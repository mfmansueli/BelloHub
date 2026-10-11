import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import { findBookingByToken, tokenHash } from '../lib/bookingAccess.js';
import { clientActions } from '../lib/clientActions.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { msOpt, plainReader, ts } from '../lib/store.js';

/** "Yes, I will be there" (Bk-9): sets `clientConfirmedAt`; the booking trigger tells the professional. Idempotent. */
export const confirmPresence = defineUseCase({
  name: 'confirmPresence',
  access: 'token',
  ...contract.confirmPresence,
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
    const already = msOpt(booking.data.clientConfirmedAt);
    if (already !== undefined) return { clientConfirmedAt: iso(already) };
    await booking.ref.update({
      clientConfirmedAt: ts(now),
      lastClientAction: { kind: 'confirmed', at: ts(now) },
      updatedAt: ts(now)
    });
    return { clientConfirmedAt: iso(now) };
  }
});
