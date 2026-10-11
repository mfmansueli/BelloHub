import { FieldValue } from 'firebase-admin/firestore';

import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import { ensureAccountExists } from '../lib/account.js';
import { tokenHash, withNewTokenHash } from '../lib/bookingAccess.js';
import { sendBookingEmail } from '../lib/bookingEmails.js';
import { bumpCalendarLock, readCalendarLock } from '../lib/calendar.js';
import { writeContact, writeRegistration } from '../lib/contacts.js';
import type { AccountDoc, ContactDoc, PublicProfileDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { loadOwnedBooking } from '../lib/ownedBooking.js';
import { consumeRate } from '../lib/rateLimit.js';
import { isPlanActive, registrationDecision } from '../lib/rules.js';
import { dataOf, msOpt, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * Approve or decline a booking that waited for her (D13, D15, D42). Approving a NEW client is what adds the client, so it
 * is where the free registrations are enforced: with them used and no plan the answer is `needsSubscription`, the
 * booking stays pending, and the app shows the paywall. Declining frees the time.
 *
 * Approving mints one more manage token (the same five-link cap) when the client gave an e-mail, so the e-mail carries
 * her exact link to change or cancel (owner, 2026-10-11). An unverified request (verify-fallback, `verification:
 * 'whatsapp'`) was never e-mailed when it was made, so it gets the full confirmation instead of the short approval.
 */
export const respondBookingRequest = defineUseCase({
  name: 'respondBookingRequest',
  access: 'owner',
  ...contract.respondBookingRequest,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    await ensureAccountExists(deps, uid, ctx);
    const r = refs(deps.db);
    const now = deps.now();
    const manageToken = deps.random.token();

    const outcome = await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const booking = await loadOwnedBooking(reader, deps.db, uid, input.bookingId);
      if (booking.data.status !== 'pendingApproval') {
        throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
      }
      const account = dataOf<AccountDoc>(await reader.doc(r.account(uid)));
      const contact = dataOf<ContactDoc>(await reader.doc(r.contact(uid, booking.data.phoneHash)));
      const profile = dataOf<PublicProfileDoc>(await reader.doc(r.profile(booking.data.slug)));
      await readCalendarLock(tx, deps.db, uid);
      if (!account) throw new AppError('NOT_FOUND');

      if (input.decision === 'decline') {
        tx.update(booking.ref, {
          status: 'declined',
          pendingReason: FieldValue.delete(),
          pendingExpiresAt: FieldValue.delete(),
          updatedAt: ts(now)
        });
        return { status: 'declined' as const, booking: { ...booking.data, status: 'declined' as const }, profile };
      }

      const isNewClient = !(contact?.registered ?? false);
      let registrationId = contact?.registrationId;
      if (isNewClient) {
        const planActive = isPlanActive({ state: account.plan.state, expiresAt: msOpt(account.plan.expiresAt) }, now);
        if (registrationDecision(account.registrations.count, planActive) === 'needsSubscription') {
          return { status: 'needsSubscription' as const, booking: booking.data, profile };
        }
        registrationId = `b_${deps.random.uuid().replaceAll('-', '')}`;
        writeRegistration(tx, r, uid, registrationId, 'booking', now);
      }
      writeContact(
        tx,
        r,
        uid,
        booking.data.phoneHash,
        contact,
        { registered: true, ...(registrationId ? { registrationId } : {}), bookingCount: (contact?.bookingCount ?? 0) + 1 },
        now
      );
      const unverified = booking.data.verification === 'whatsapp';
      const mints = booking.data.client.email !== undefined;
      const hashes = mints ? withNewTokenHash(booking.data.manageTokenHashes, tokenHash(manageToken)) : undefined;
      tx.update(booking.ref, {
        status: 'confirmed',
        pendingReason: FieldValue.delete(),
        pendingExpiresAt: FieldValue.delete(),
        ...(hashes ? { manageTokenHashes: hashes } : {}),
        updatedAt: ts(now)
      });
      bumpCalendarLock(tx, deps.db, uid);
      return {
        status: 'confirmed' as const,
        booking: { ...booking.data, status: 'confirmed' as const },
        profile,
        unverified,
        ...(mints ? { manageToken } : {})
      };
    });

    if (outcome.status !== 'needsSubscription') {
      await sendBookingEmail(deps, {
        // An approved unverified request gets the full confirmation (it carries the personal link): she never had one.
        template:
          outcome.status === 'confirmed'
            ? 'unverified' in outcome && outcome.unverified
              ? 'bookingConfirmed'
              : 'bookingApproved'
            : 'bookingDeclined',
        booking: outcome.booking,
        professionalName: outcome.profile?.displayName ?? '',
        ...('manageToken' in outcome && outcome.manageToken ? { manageToken: outcome.manageToken } : { linkToPage: true })
      });
    }
    deps.log.info('booking.responded', { uid, bookingId: input.bookingId, decision: outcome.status });
    return { status: outcome.status };
  }
});
