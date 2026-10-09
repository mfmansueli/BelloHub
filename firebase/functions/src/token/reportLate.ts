import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import { findBookingByToken, tokenHash } from '../lib/bookingAccess.js';
import { clientActions } from '../lib/clientActions.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { plainReader, ts } from '../lib/store.js';

/** "I am running late" (10, 15, 20 or 30 minutes): the trigger sends the professional an urgent generic push. */
export const reportLate = defineUseCase({
  name: 'reportLate',
  access: 'token',
  ...contract.reportLate,
  async handle(deps, input, ctx) {
    await consumeRates(deps, [
      { scope: 'tokenAction', subject: tokenHash(input.token), rate: RATE.tokenActionsToken },
      { scope: 'tokenIp', subject: ctx.ipHash, rate: RATE.tokenCallsIp }
    ]);
    const now = deps.now();
    const booking = await findBookingByToken(plainReader, deps.db, input.token, now);
    const actions = clientActions(booking.data, now);
    if (booking.data.status !== 'confirmed' || actions.phase === 'past') {
      throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
    }
    // Too early is not a state of the booking, it is a rule: running late is reported on the day, not days ahead.
    if (!actions.canReportLate) throw new AppError('NOT_ALLOWED');
    await booking.ref.update({
      lateByMinutes: input.minutes,
      lateReportedAt: ts(now),
      lastClientAction: { kind: 'late', at: ts(now) },
      updatedAt: ts(now)
    });
    return { lateByMinutes: input.minutes, reportedAt: iso(now) };
  }
});
