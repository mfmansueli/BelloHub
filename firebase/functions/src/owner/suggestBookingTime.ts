import { FieldValue } from 'firebase-admin/firestore';

import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { OFFER_DEFAULT_MINUTES, RATE } from '../config/limits.js';
import { instantMs, iso } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import { ensureAccountExists } from '../lib/account.js';
import { bumpCalendarLock, checkSlot, loadCalendar, readCalendarLock, resolveOffer, timingFields } from '../lib/calendar.js';
import type { HoldDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { holdKeyHash } from '../lib/holds.js';
import { loadOwnedBooking } from '../lib/ownedBooking.js';
import { consumeRate } from '../lib/rateLimit.js';
import { refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * "Suggest another time" on a booking request (2.10): instead of a bare decline, she proposes a time that suits her. The
 * request is declined and the proposed time is held for the client like a waitlist offer: the server returns a
 * one-time key for the link the app sends on WhatsApp (`<web>/<slug>/time?offer=<holdKey>`), and booking through it
 * follows her usual rules. The same service, add-ons and guests as the request. No email: the message comes from her.
 */
export const suggestBookingTime = defineUseCase({
  name: 'suggestBookingTime',
  access: 'owner',
  ...contract.suggestBookingTime,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    const account = await ensureAccountExists(deps, uid, ctx);
    if (!account.slug) throw new AppError('NOT_FOUND');
    const slug = account.slug;
    const now = deps.now();
    const startsAt = instantMs(input.startsAt);
    const holdKey = deps.random.token();
    const minutes = input.holdMinutes ?? OFFER_DEFAULT_MINUTES;

    const outcome = await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const booking = await loadOwnedBooking(reader, deps.db, uid, input.bookingId);
      if (booking.data.status !== 'pendingApproval') {
        throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
      }
      const calendar = await loadCalendar(reader, deps.db, slug);
      if (!calendar) throw new AppError('NOT_FOUND');
      const offer = resolveOffer(calendar.profile, {
        serviceId: booking.data.serviceId,
        addOnIds: booking.data.addOns.map((addOn) => addOn.id),
        guests: booking.data.guestCount
      });
      await readCalendarLock(tx, deps.db, uid);
      const check = await checkSlot(reader, deps.db, calendar, startsAt, offer, now);
      if (!check.free) return { status: 'slotTaken' as const };

      const expiresAt = now + minutes * 60_000;
      const holdRef = refs(deps.db).holds().doc();
      tx.create(holdRef, {
        ownerUid: uid,
        slug,
        serviceId: offer.serviceId,
        addOnIds: offer.addOns.map((addOn) => addOn.id),
        guests: offer.guests,
        startsAt: ts(startsAt),
        endsAt: ts(startsAt + offer.durationMinutes * 60_000),
        ...timingFields(offer.timing),
        expiresAt: ts(expiresAt),
        holdKeyHash: holdKeyHash(holdKey),
        kind: 'offer',
        suggestedForBookingId: input.bookingId
      } satisfies HoldDoc);
      tx.update(booking.ref, { status: 'declined', pendingReason: FieldValue.delete(), updatedAt: ts(now) });
      bumpCalendarLock(tx, deps.db, uid);
      return { status: 'suggested' as const, holdKey, holdId: holdRef.id, expiresAt: iso(expiresAt) };
    });
    deps.log.info('booking.suggested', { uid, bookingId: input.bookingId, status: outcome.status });
    return outcome;
  }
});
