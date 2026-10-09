// The one place a booking is made: createBooking (a new client), rebook (a returning one) and the waitlist offer all go
// through it. One Firestore transaction (D32) decides pause, no-show action, the free-registration branch (D42) and
// the slot, and writes the booking. See calendar.ts for how two simultaneous callers cannot both win.

import type { Transaction } from 'firebase-admin/firestore';
import { FieldValue } from 'firebase-admin/firestore';

import type { Deps } from '../app/Deps.js';
import { RATE } from '../config/limits.js';
import type { LocaleId } from '../contracts/common.js';
import { iso } from '../contracts/common.js';
import { tokenHash, withNewTokenHash } from './bookingAccess.js';
import { sendBookingEmail } from './bookingEmails.js';
import type { OfferInput } from './calendar.js';
import { bumpCalendarLock, checkSlot, loadCalendar, readCalendarLock, resolveOffer } from './calendar.js';
import { noShowState, writeContact, writeRegistration } from './contacts.js';
import { sha256Hex } from './crypto.js';
import type { BookingDoc, ContactDoc, IdempotencyDoc, WaitlistDoc } from './docs.js';
import { ACTIVE_BOOKING_STATUSES } from './docs.js';
import { emailHashOf, peekEmailProof, phoneHashOf, proofHash, useEmailProof } from './emailProof.js';
import { AppError } from './errors.js';
import { findHoldsByKey, holdKeyHash } from './holds.js';
import { consumeRate, consumeRates } from './rateLimit.js';
import type { NoShowPolicy } from './rules.js';
import { approvalReason, isPausedFor, isPlanActive, purgeAtFor } from './rules.js';
import { dataOf, ms, msOpt, refs, ts, txReader } from './store.js';
import { runTransaction } from './tx.js';

export interface BookingClient {
  name: string;
  phone: string;
  email?: string | undefined;
  locale: LocaleId;
}

export type Proof =
  /** A phone ID token, already verified by the caller against `client.phone`. */
  | { kind: 'phone' }
  /** An email proof from verifyEmailCode, checked and consumed inside the transaction. */
  | { kind: 'email'; proof: string }
  /** The caller holds a manage or portal token of a booking of this client (rebook). */
  | { kind: 'token' };

export interface CreateBookingRequest {
  slug: string;
  offer: OfferInput;
  startsAt: number;
  client: BookingClient;
  note?: string | undefined;
  idempotencyKey: string;
  holdKey?: string | undefined;
  origin: BookingDoc['origin'];
  proof: Proof;
  /** Rate limit subjects. */
  ipHash: string;
}

export type BookingOutcome =
  | {
      status: 'confirmed' | 'pendingApproval';
      bookingId: string;
      manageToken: string;
      startsAt: string;
      endsAt: string;
      timeZoneID: string;
      serviceName: string;
      emailSent: boolean;
    }
  | { status: 'slotTaken'; alternatives: string[] }
  | { status: 'paused'; pausedUntil?: string };

type TxResult =
  | { kind: 'done'; outcome: BookingOutcome }
  | { kind: 'created'; booking: BookingDoc; bookingId: string; professionalName: string; replay: boolean };

const NO_NO_SHOW_POLICY: NoShowPolicy = { isOn: false, limit: 3, action: 'tell', lateCancelCounts: false, countingMonths: 12 };

export async function createBookingCore(deps: Deps, request: CreateBookingRequest): Promise<BookingOutcome> {
  const r = refs(deps.db);
  const claim = await r.slug(request.slug).get();
  if (!claim.exists) throw new AppError('NOT_FOUND');
  const ownerUid = (claim.data() as { ownerUid: string }).ownerUid;

  const now = deps.now();
  const phoneHash = phoneHashOf(deps.pepper, request.client.phone);
  // The caller's own address pays for every attempt; the phone and the professional only once the proof looks real,
  // so a stranger with made-up proofs cannot use up a client's or a professional's allowance.
  await consumeRate(deps, 'createBookingIp', request.ipHash, RATE.createBookingIp);
  if (request.proof.kind === 'email') {
    await peekEmailProof(deps.db, deps.pepper, request.proof.proof, request.client.email ?? '', now);
  }
  await consumeRates(deps, [
    { scope: 'createBookingPhone', subject: phoneHash, rate: RATE.createBookingPhone },
    { scope: 'createBookingOwner', subject: ownerUid, rate: RATE.createBookingOwnerDay }
  ]);

  const manageToken = deps.random.token();
  const idemKey = sha256Hex(`idem:${request.slug}:${request.idempotencyKey}`);
  const fingerprint = sha256Hex(
    JSON.stringify([
      request.offer.serviceId,
      [...(request.offer.addOnIds ?? [])].sort(),
      request.offer.guests ?? 0,
      request.startsAt,
      request.client.phone
    ])
  );
  const holdHash = request.holdKey ? holdKeyHash(request.holdKey) : undefined;

  const result = await runTransaction(deps.db, async (tx): Promise<TxResult> => {
    const reader = txReader(tx);

    // ---- reads (a Firestore transaction reads everything before it writes) ----
    const calendar = await loadCalendar(reader, deps.db, request.slug);
    if (!calendar) throw new AppError('NOT_FOUND');
    const idem = dataOf<IdempotencyDoc>(await reader.doc(r.idempotency(idemKey)));
    if (idem) {
      if (idem.fingerprint !== fingerprint) throw new AppError('CONFLICT');
      return replay(deps, tx, idem, request, now, manageToken, calendar.profile.displayName);
    }

    const releaseProof =
      request.proof.kind === 'email'
        ? await useEmailProof(tx, deps.db, deps.pepper, request.proof.proof, request.client.email ?? '', now)
        : undefined;
    const contact = dataOf<ContactDoc>(await reader.doc(r.contact(ownerUid, phoneHash)));
    await readCalendarLock(tx, deps.db, ownerUid);
    const ownHolds = request.holdKey ? await findHoldsByKey(reader, deps.db, ownerUid, request.holdKey) : [];
    const waitlistIds = [...new Set(ownHolds.map((hold) => hold.data.waitlistId).filter((id): id is string => !!id))];
    const waitlistDocs = await Promise.all(waitlistIds.map((id) => reader.doc(r.waitlistEntry(id))));

    const { profile, availability, account } = calendar;
    const offer = resolveOffer(profile, request.offer);
    const noShowPolicy = availability?.noShow ?? NO_NO_SHOW_POLICY;
    const noShow = noShowState(noShowPolicy, contact, now);
    const noShowAction = noShowPolicy.isOn ? noShowPolicy.action : undefined;

    // ---- pause ----
    const pausedUntil = msOpt(profile.booking.pausedUntil);
    const pagePaused = !profile.booking.acceptingBookings || (pausedUntil !== undefined && pausedUntil > now);
    if (
      isPausedFor({
        acceptingBookings: profile.booking.acceptingBookings,
        pausedUntil,
        now,
        noShowAction,
        noShowLimitReached: noShow.limitReached,
        onlineBookingStopped: contact?.onlineBookingStopped ?? false
      })
    ) {
      const showDate = pagePaused && pausedUntil !== undefined && pausedUntil > now;
      return { kind: 'done', outcome: { status: 'paused', ...(showDate ? { pausedUntil: iso(pausedUntil) } : {}) } };
    }

    // ---- the slot ----
    const check = await checkSlot(reader, deps.db, calendar, request.startsAt, offer.durationMinutes, now, {
      ownHoldKeyHash: holdHash
    });
    if (!check.free) {
      return { kind: 'done', outcome: { status: 'slotTaken', alternatives: check.alternatives.map(iso) } };
    }

    // ---- the decision (D13, D15, D42) ----
    const isNewClient = !(contact?.registered ?? false);
    const reason = approvalReason({
      confirmNewClients: profile.booking.requiresApproval,
      isNewClient,
      registrationCount: account.registrations.count,
      planActive: isPlanActive(
        { state: account.plan.state, expiresAt: msOpt(account.plan.expiresAt) },
        now
      ),
      noShowAction,
      noShowLimitReached: noShow.limitReached
    });
    const status = reason ? 'pendingApproval' : 'confirmed';

    // ---- writes ----
    const endsAt = request.startsAt + offer.durationMinutes * 60_000;
    const bookingRef = r.bookings().doc();
    const booking: BookingDoc = {
      schemaVersion: 1,
      ownerUid,
      slug: request.slug,
      status,
      ...(reason ? { pendingReason: reason } : {}),
      serviceId: offer.serviceId,
      serviceName: offer.serviceName,
      durationMinutes: offer.durationMinutes,
      addOns: offer.addOns,
      guestCount: offer.guests,
      startsAt: ts(request.startsAt),
      endsAt: ts(endsAt),
      timeZoneID: availability?.timeZoneID ?? profile.timeZoneID,
      client: {
        name: request.client.name,
        phone: request.client.phone,
        ...(request.client.email ? { email: request.client.email } : {}),
        locale: request.client.locale
      },
      phoneHash,
      ...(request.client.email ? { emailHash: emailHashOf(deps.pepper, request.client.email) } : {}),
      ...(request.note ? { note: request.note } : {}),
      manageTokenHashes: [tokenHash(manageToken)],
      // Booking through a link she sent from the waitlist is a waitlist booking.
      origin: ownHolds.some((hold) => hold.data.kind === 'offer') ? 'waitlist' : request.origin,
      policy: profile.policy,
      rescheduleCount: 0,
      createdAt: ts(now),
      updatedAt: ts(now),
      purgeAt: ts(purgeAtFor(endsAt))
    };
    tx.create(bookingRef, booking);
    tx.create(r.idempotency(idemKey), {
      bookingId: bookingRef.id,
      ownerUid,
      fingerprint,
      ...(request.proof.kind === 'email' ? { proofHash: proofHash(request.proof.proof) } : {}),
      expiresAt: booking.purgeAt
    } satisfies IdempotencyDoc);

    if (status === 'confirmed') {
      // A confirmed booking from an unknown phone makes her a client of this professional: it counts toward the free
      // registrations at once (D42), keyed by the phone so the app's later reserveRegistration does not count twice.
      let registrationId = contact?.registrationId;
      if (isNewClient) {
        registrationId = `b_${deps.random.uuid().replaceAll('-', '')}`;
        writeRegistration(tx, r, ownerUid, registrationId, 'booking', now);
      }
      writeContact(
        tx,
        r,
        ownerUid,
        phoneHash,
        contact,
        {
          registered: true,
          ...(registrationId ? { registrationId } : {}),
          bookingCount: (contact?.bookingCount ?? 0) + 1
        },
        now
      );
    }

    for (const hold of ownHolds) tx.delete(hold.snapshot.ref);
    waitlistDocs.forEach((snapshot) => {
      if (snapshot.exists) tx.update(snapshot.ref, { status: 'booked' } satisfies Partial<WaitlistDoc>);
    });
    releaseProof?.();
    bumpCalendarLock(tx, deps.db, ownerUid);
    return { kind: 'created', booking, bookingId: bookingRef.id, professionalName: profile.displayName, replay: false };
  });

  if (result.kind === 'done') return result.outcome;
  const { booking, bookingId } = result;
  // A replay was already emailed the first time.
  const emailSent = result.replay
    ? false
    : await sendBookingEmail(deps, {
        template: booking.status === 'confirmed' ? 'bookingConfirmed' : 'bookingPending',
        booking,
        professionalName: result.professionalName,
        manageToken
      });
  deps.log.info('booking.created', { bookingId, ownerUid, status: booking.status, kind: request.origin });
  return {
    status: booking.status as 'confirmed' | 'pendingApproval',
    bookingId,
    manageToken,
    startsAt: iso(ms(booking.startsAt)),
    endsAt: iso(ms(booking.endsAt)),
    timeZoneID: booking.timeZoneID,
    serviceName: booking.serviceName,
    emailSent
  };
}

/**
 * The same request again (a lost response, a double tap): the same booking, with one more valid token. A replay hands
 * out a manage token, so it must show the verification the booking was made with: a phone token was checked by the
 * caller against the phone in the fingerprint; an email proof must be the one already spent on this booking, or a fresh
 * valid one for the same address (spent here). An idempotency key alone opens nothing.
 */
async function replay(
  deps: Deps,
  tx: Transaction,
  idem: IdempotencyDoc,
  request: CreateBookingRequest,
  now: number,
  manageToken: string,
  professionalName: string
): Promise<TxResult> {
  const r = refs(deps.db);
  const ref = r.booking(idem.bookingId);
  const booking = dataOf<BookingDoc>(await tx.get(ref));
  if (!booking || !ACTIVE_BOOKING_STATUSES.includes(booking.status)) throw new AppError('BOOKING_NOT_ACTIVE');
  const releaseProof =
    request.proof.kind === 'email' && proofHash(request.proof.proof) !== idem.proofHash
      ? await useEmailProof(tx, deps.db, deps.pepper, request.proof.proof, request.client.email ?? '', now)
      : undefined;
  const hashes = withNewTokenHash(booking.manageTokenHashes, tokenHash(manageToken));
  tx.update(ref, { manageTokenHashes: hashes, updatedAt: FieldValue.serverTimestamp() });
  releaseProof?.();
  return { kind: 'created', booking: { ...booking, manageTokenHashes: hashes }, bookingId: ref.id, professionalName, replay: true };
}
