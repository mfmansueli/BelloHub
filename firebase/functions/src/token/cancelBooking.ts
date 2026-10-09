import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/public.js';
import { findBookingByToken, tokenHash } from '../lib/bookingAccess.js';
import { clientActions } from '../lib/clientActions.js';
import { withMark, writeContact } from '../lib/contacts.js';
import type { ContactDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { dataOf, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * Cancel (Cl-6): free inside the window; after it, allowed with an honest warning (D12) or "message her", by the policy
 * copied onto the booking. A late cancellation is recorded as a mark when the no-show policy OF BOOKING TIME said it
 * counts (D13, D47); bookings made before the snapshot existed keep the old behaviour (always recorded, counted by the
 * live policy). Cancelling frees the time at once; the booking trigger matches the waitlist.
 */
export const cancelBooking = defineUseCase({
  name: 'cancelBooking',
  access: 'token',
  ...contract.cancelBooking,
  async handle(deps, input, ctx) {
    await consumeRates(deps, [
      { scope: 'tokenAction', subject: tokenHash(input.token), rate: RATE.tokenActionsToken },
      { scope: 'tokenIp', subject: ctx.ipHash, rate: RATE.tokenCallsIp }
    ]);
    const now = deps.now();
    const r = refs(deps.db);
    const reason = input.reason?.length ? input.reason : undefined;

    return runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const booking = await findBookingByToken(reader, deps.db, input.token, now);
      const actions = clientActions(booking.data, now);
      if (actions.cancel === 'unavailable') throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
      if (actions.cancel === 'askByMessage') throw new AppError('NOT_ALLOWED', { action: 'message' });
      if (actions.cancel === 'allowedWithWarning' && input.acceptLateWarning !== true) {
        throw new AppError('CONFIRMATION_REQUIRED');
      }
      const isLate = actions.cancel === 'allowedWithWarning';
      const contact = dataOf<ContactDoc>(await reader.doc(r.contact(booking.data.ownerUid, booking.data.phoneHash)));

      tx.update(booking.ref, {
        status: 'cancelledByClient',
        cancelledBy: 'client',
        cancelledAt: ts(now),
        isLateCancellation: isLate,
        ...(reason ? { cancelReason: reason } : {}),
        lastClientAction: { kind: 'cancelled', at: ts(now) },
        updatedAt: ts(now)
      });
      const lateCounts = booking.data.noShowPolicy ? booking.data.noShowPolicy.isOn && booking.data.noShowPolicy.lateCancelCounts : true;
      if (isLate && lateCounts) {
        const marks = withMark(contact?.marks, { id: `lc_${booking.id}`, at: now, kind: 'lateCancel' });
        writeContact(tx, r, booking.data.ownerUid, booking.data.phoneHash, contact, { marks }, now);
      }
      return { status: 'cancelled' as const, isLateCancellation: isLate };
    });
  }
});
