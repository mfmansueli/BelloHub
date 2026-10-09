import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { instantMs, iso } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import { findBookingByToken, tokenHash } from '../lib/bookingAccess.js';
import { checkSlot, loadCalendar } from '../lib/calendar.js';
import type { RescheduleRequestDoc } from '../lib/docs.js';
import { ACTIVE_BOOKING_STATUSES } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { clientActions } from '../lib/clientActions.js';
import { plainReader, refs, ts } from '../lib/store.js';
import { notifyOwner } from '../push/notifyOwner.js';

/**
 * After the free window the client may ASK to move (docs/10 section 4). The current time stays reserved until the
 * professional answers: a request reserves nothing, so it needs no calendar lock. One open request per booking (the
 * request document id is the booking id).
 */
export const requestReschedule = defineUseCase({
  name: 'requestReschedule',
  access: 'token',
  ...contract.requestReschedule,
  async handle(deps, input, ctx) {
    await consumeRates(deps, [
      { scope: 'tokenAction', subject: tokenHash(input.token), rate: RATE.tokenActionsToken },
      { scope: 'tokenIp', subject: ctx.ipHash, rate: RATE.tokenCallsIp }
    ]);
    const now = deps.now();
    const requestedStart = instantMs(input.startsAt);
    const booking = await findBookingByToken(plainReader, deps.db, input.token, now);
    if (!ACTIVE_BOOKING_STATUSES.includes(booking.data.status)) {
      throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
    }
    const actions = clientActions(booking.data, now);
    if (actions.reschedule === 'unavailable') throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
    if (actions.reschedule !== 'request') throw new AppError('NOT_ALLOWED', { action: actions.reschedule });

    const calendar = await loadCalendar(plainReader, deps.db, booking.data.slug);
    if (!calendar) throw new AppError('NOT_FOUND');
    const check = await checkSlot(plainReader, deps.db, calendar, requestedStart, booking.data.durationMinutes, now, {
      excludeBookingId: booking.id
    });
    if (!check.free) return { status: 'slotTaken' as const, alternatives: check.alternatives.map(iso) };

    const requestedEnd = requestedStart + booking.data.durationMinutes * 60_000;
    const doc: RescheduleRequestDoc = {
      ownerUid: booking.data.ownerUid,
      bookingId: booking.id,
      clientName: booking.data.client.name,
      serviceName: booking.data.serviceName,
      currentStart: booking.data.startsAt,
      currentEnd: booking.data.endsAt,
      requestedStart: ts(requestedStart),
      requestedEnd: ts(requestedEnd),
      ...(input.note ? { note: input.note } : {}),
      status: 'pending',
      createdAt: ts(now),
      purgeAt: booking.data.purgeAt
    };
    await refs(deps.db).rescheduleRequest(booking.id).set(doc);
    await notifyOwner(deps, booking.data.ownerUid, { kind: 'rescheduleRequest', id: booking.id });
    return { status: 'requested' as const };
  }
});
