import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import { findBookingByToken, tokenHash } from '../lib/bookingAccess.js';
import { clientActions } from '../lib/clientActions.js';
import { emailHashOf, phoneHashOf } from '../lib/emailProof.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { msOpt, plainReader, ts } from '../lib/store.js';

/** "Yes, I will be there" (Bk-9): sets `clientConfirmedAt`, updates client contact if provided; the booking trigger tells the professional. */
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

    let email = booking.data.client.email;
    let phone = booking.data.client.phone;

    const already = msOpt(booking.data.clientConfirmedAt);
    if (already !== undefined && !input.client) {
      return {
        clientConfirmedAt: iso(already),
        ...(email ? { email } : {}),
        ...(phone ? { phone } : {})
      };
    }

    const updates: Record<string, unknown> = {
      clientConfirmedAt: ts(now),
      lastClientAction: { kind: 'confirmed', at: ts(now) },
      updatedAt: ts(now)
    };

    if (input.client?.email) {
      email = input.client.email;
      updates['client.email'] = email;
      updates.emailHash = emailHashOf(deps.pepper, email);
    }
    if (input.client?.phone) {
      phone = input.client.phone;
      updates['client.phone'] = phone;
      updates.phoneHash = phoneHashOf(deps.pepper, phone);
    }

    await booking.ref.update(updates);
    return {
      clientConfirmedAt: iso(now),
      ...(email ? { email } : {}),
      ...(phone ? { phone } : {})
    };
  }
});
