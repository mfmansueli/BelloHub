// The one place a booking is made: createBooking (a new client), rebook (a returning one) and the waitlist offer all go
// through it. One Firestore transaction (D32) decides pause, no-show action, the free-registration branch (D42) and
// the slot, and writes the booking. See calendar.ts for how two simultaneous callers cannot both win.

import type { Transaction } from 'firebase-admin/firestore';
import { FieldValue } from 'firebase-admin/firestore';

import type { Deps } from '../app/Deps.js';
import { MAX_PENDING_UNVERIFIED_PER_CONTACT, RATE } from '../config/limits.js';
import type { LocaleId } from '../contracts/common.js';
import { iso } from '../contracts/common.js';
import { tokenHash, withNewTokenHash } from './bookingAccess.js';
import { sendBookingEmail } from './bookingEmails.js';
import type { OfferInput } from './calendar.js';
import { bumpCalendarLock, checkSlot, loadCalendar, readCalendarLock, resolveOffer, timingFields } from './calendar.js';
import { noShowState, writeContact, writeRegistration } from './contacts.js';
import { sha256Hex } from './crypto.js';
import type { BookingDoc, ContactDoc, IdempotencyDoc, WaitlistDoc } from './docs.js';
import { ACTIVE_BOOKING_STATUSES } from './docs.js';
import { emailHashOf, peekEmailProof, phoneHashOf, proofHash, useEmailProof } from './emailProof.js';
import { AppError } from './errors.js';
import { findHoldsByKey, holdKeyHash } from './holds.js';
import { consumeRate, consumeRates } from './rateLimit.js';
import { newReference, requestExpiry } from './unverifiedRequests.js';
import { issueTrustedDevice, peekTrustedDevice, useTrustedDevice } from './trustedDevices.js';
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
  | { kind: 'token' }
  /** A trusted-device token for this page and `client.email` (returning client, verify-fallback item 2). */
  | { kind: 'device'; token: string }
  /** No proof: the client confirms with the professional on WhatsApp. Always a request, flagged unverified. */
  | { kind: 'whatsapp' };

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
      reference?: string;
      requestExpiresAt?: string;
      deviceToken?: string;
      deviceTokenExpiresAt?: string;
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
  const proof = request.proof;
  const email = request.client.email ?? '';
  if (proof.kind === 'email') {
    await peekEmailProof(deps.db, deps.pepper, proof.proof, email, now);
  } else if (proof.kind === 'device') {
    await peekTrustedDevice(deps.db, deps.pepper, proof.token, request.slug, email, now);
  } else if (proof.kind === 'whatsapp') {
    // Nothing is proven, so every subject pays: the caller, the address, the phone and the professional's day.
    await consumeRates(deps, [
      { scope: 'unverifiedIp', subject: request.ipHash, rate: RATE.unverifiedIp },
      { scope: 'unverifiedEmail', subject: emailHashOf(deps.pepper, email), rate: RATE.unverifiedEmail },
      { scope: 'unverifiedPhone', subject: phoneHash, rate: RATE.unverifiedPhone },
      { scope: 'unverifiedOwner', subject: ownerUid, rate: RATE.unverifiedOwnerDay }
    ]);
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
  const emailHash = request.client.email ? emailHashOf(deps.pepper, request.client.email) : undefined;

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
      proof.kind === 'email'
        ? await useEmailProof(tx, deps.db, deps.pepper, proof.proof, email, now)
        : proof.kind === 'device'
          ? await useTrustedDevice(tx, deps.db, deps.pepper, proof.token, request.slug, email, now)
          : undefined;
    if (proof.kind === 'whatsapp') {
      await refusePendingUnverified(reader, deps, ownerUid, phoneHash, emailHash, now);
    }
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
    const check = await checkSlot(reader, deps.db, calendar, request.startsAt, offer, now, {
      ownHoldKeyHash: holdHash
    });
    if (!check.free) {
      return { kind: 'done', outcome: { status: 'slotTaken', alternatives: check.alternatives.map(iso) } };
    }

    if (proof.kind === 'whatsapp' && !profile.whatsappE164) {
      // The fallback exists only when she has a public WhatsApp number to confirm with.
      throw new AppError('NOT_ALLOWED');
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
    if (proof.kind === 'device' && (reason !== null || noShow.limitReached)) {
      // A trusted device skips the code only for a booking confirmed at once; anything she must look at goes back to
      // the code, so an approval is never decided on an old proof.
      throw new AppError('VERIFICATION_REQUIRED');
    }
    const unverified = proof.kind === 'whatsapp';
    const status = reason || unverified ? 'pendingApproval' : 'confirmed';

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
      // D56: the shape of the visit is kept with it, so editing the service later never moves what is booked.
      ...timingFields(offer.timing),
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
      // A waitlist offer makes a waitlist booking; a suggested time (no waitlist entry) keeps the request's origin.
      origin: ownHolds.some((hold) => hold.data.kind === 'offer' && hold.data.waitlistId) ? 'waitlist' : request.origin,
      // D47: the rules she published now apply to this booking for good; `rulesText` goes with them.
      policy: profile.policy,
      rulesText: profile.rulesText,
      noShowPolicy: { isOn: noShowPolicy.isOn, limit: noShowPolicy.limit, lateCancelCounts: noShowPolicy.lateCancelCounts },
      rescheduleCount: 0,
      createdAt: ts(now),
      updatedAt: ts(now),
      purgeAt: ts(purgeAtFor(endsAt)),
      ...(unverified
        ? {
            verification: 'whatsapp' as const,
            reference: newReference(deps.random),
            pendingExpiresAt: ts(requestExpiry(now, request.startsAt))
          }
        : {})
    };
    tx.create(bookingRef, booking);
    tx.create(r.idempotency(idemKey), {
      bookingId: bookingRef.id,
      ownerUid,
      fingerprint,
      ...(proof.kind === 'email' ? { proofHash: proofHash(proof.proof) } : {}),
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
  // A replay was already emailed the first time. An unverified request is not emailed at all: the address is not
  // proven, and the server must not mail a stranger on anyone's word. She gets the link when it is approved.
  const emailSent =
    result.replay || booking.verification === 'whatsapp'
      ? false
      : await sendBookingEmail(deps, {
          template: booking.status === 'confirmed' ? 'bookingConfirmed' : 'bookingPending',
          booking,
          professionalName: result.professionalName,
          manageToken
        });
  // Item 2: a confirmed booking with a fresh code makes this browser a trusted device for this page and address.
  const device =
    !result.replay && proof.kind === 'email' && booking.status === 'confirmed' && request.client.email
      ? await issueTrustedDevice(deps, { ownerUid, slug: request.slug, email: request.client.email, phoneHash })
      : undefined;
  deps.log.info('booking.created', { bookingId, ownerUid, status: booking.status, kind: request.origin });
  return {
    status: booking.status as 'confirmed' | 'pendingApproval',
    bookingId,
    manageToken,
    startsAt: iso(ms(booking.startsAt)),
    endsAt: iso(ms(booking.endsAt)),
    timeZoneID: booking.timeZoneID,
    serviceName: booking.serviceName,
    emailSent,
    ...(booking.reference ? { reference: booking.reference } : {}),
    ...(booking.pendingExpiresAt && booking.status === 'pendingApproval'
      ? { requestExpiresAt: iso(ms(booking.pendingExpiresAt)) }
      : {}),
    ...(device ? { deviceToken: device.token, deviceTokenExpiresAt: iso(device.expiresAt) } : {})
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
  const proof = request.proof;
  const email = request.client.email ?? '';
  // An unverified request can only replay an unverified request: the same key never upgrades or downgrades a proof.
  if ((proof.kind === 'whatsapp') !== (booking.verification === 'whatsapp')) throw new AppError('VERIFICATION_FAILED');
  const releaseProof =
    proof.kind === 'email' && proofHash(proof.proof) !== idem.proofHash
      ? await useEmailProof(tx, deps.db, deps.pepper, proof.proof, email, now)
      : proof.kind === 'device'
        ? await useTrustedDevice(tx, deps.db, deps.pepper, proof.token, request.slug, email, now)
        : undefined;
  const hashes = withNewTokenHash(booking.manageTokenHashes, tokenHash(manageToken));
  tx.update(ref, { manageTokenHashes: hashes, updatedAt: FieldValue.serverTimestamp() });
  releaseProof?.();
  return { kind: 'created', booking: { ...booking, manageTokenHashes: hashes }, bookingId: ref.id, professionalName, replay: true };
}

/**
 * Caps the unverified requests one contact may leave waiting with one professional (verify-fallback item 1): two at a
 * time per phone and per address. Read inside the booking transaction, so two calls at once cannot both pass the cap.
 */
async function refusePendingUnverified(
  reader: ReturnType<typeof txReader>,
  deps: Deps,
  ownerUid: string,
  phoneHash: string,
  emailHash: string | undefined,
  now: number
): Promise<void> {
  const r = refs(deps.db);
  const byPhone = await reader.query(r.bookings().where('ownerUid', '==', ownerUid).where('phoneHash', '==', phoneHash));
  const byEmail = emailHash
    ? await reader.query(r.bookings().where('ownerUid', '==', ownerUid).where('emailHash', '==', emailHash))
    : undefined;
  const waiting = (docs: readonly { data(): unknown }[]): BookingDoc[] =>
    docs
      .map((doc) => doc.data() as BookingDoc)
      .filter(
        (booking) =>
          booking.status === 'pendingApproval' &&
          booking.verification === 'whatsapp' &&
          (msOpt(booking.pendingExpiresAt) ?? 0) > now
      );
  for (const found of [waiting(byPhone.docs), waiting(byEmail?.docs ?? [])]) {
    if (found.length >= MAX_PENDING_UNVERIFIED_PER_CONTACT) {
      const soonest = Math.min(...found.map((booking) => msOpt(booking.pendingExpiresAt) ?? now));
      throw new AppError('RATE_LIMITED', { retryAfterSeconds: Math.max(1, Math.ceil((soonest - now) / 1000)) });
    }
  }
}
