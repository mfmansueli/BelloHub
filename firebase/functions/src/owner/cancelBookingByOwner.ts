import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import { sendBookingEmail } from '../lib/bookingEmails.js';
import type { PublicProfileDoc } from '../lib/docs.js';
import { ACTIVE_BOOKING_STATUSES } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { loadOwnedBooking } from '../lib/ownedBooking.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * She cancels a booking that came from the link. It never counts against the client (D13): `cancelledBy` is
 * "professional" and `isLateCancellation` stays false. The client is told by email when she gave one.
 */
export const cancelBookingByOwner = defineUseCase({
  name: 'cancelBookingByOwner',
  access: 'owner',
  ...contract.cancelBookingByOwner,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    const now = deps.now();
    const reason = input.reason?.length ? input.reason : undefined;

    const result = await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const booking = await loadOwnedBooking(reader, deps.db, uid, input.bookingId);
      if (!ACTIVE_BOOKING_STATUSES.includes(booking.data.status)) {
        throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
      }
      const profile = dataOf<PublicProfileDoc>(await reader.doc(refs(deps.db).profile(booking.data.slug)));
      tx.update(booking.ref, {
        status: 'cancelledByPro',
        cancelledBy: 'professional',
        cancelledAt: ts(now),
        isLateCancellation: false,
        ...(reason ? { cancelReason: reason } : {}),
        updatedAt: ts(now)
      });
      return { booking: booking.data, name: profile?.displayName ?? '' };
    });

    await sendBookingEmail(deps, {
      template: 'bookingCancelled',
      booking: result.booking,
      professionalName: result.name,
      linkToPage: true
    });
    return { status: 'cancelled' as const };
  }
});
