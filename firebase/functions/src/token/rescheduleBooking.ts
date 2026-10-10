import { FieldValue } from 'firebase-admin/firestore';

import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { instantMs, iso } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import { findBookingByToken, tokenHash } from '../lib/bookingAccess.js';
import { bookingOffer, bumpCalendarLock, checkSlot, loadCalendar, readCalendarLock } from '../lib/calendar.js';
import { ACTIVE_BOOKING_STATUSES } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { clientActions } from '../lib/clientActions.js';
import { purgeAtFor } from '../lib/rules.js';
import { ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/** "Direct" rescheduling (docs/10 section 4): inside the free window the client picks a new time and it moves at once. */
export const rescheduleBooking = defineUseCase({
  name: 'rescheduleBooking',
  access: 'token',
  ...contract.rescheduleBooking,
  async handle(deps, input, ctx) {
    await consumeRates(deps, [
      { scope: 'tokenAction', subject: tokenHash(input.token), rate: RATE.tokenActionsToken },
      { scope: 'tokenIp', subject: ctx.ipHash, rate: RATE.tokenCallsIp }
    ]);
    const now = deps.now();
    const startsAt = instantMs(input.startsAt);

    return runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const booking = await findBookingByToken(reader, deps.db, input.token, now);
      if (!ACTIVE_BOOKING_STATUSES.includes(booking.data.status)) {
        throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
      }
      const actions = clientActions(booking.data, now);
      if (actions.reschedule === 'unavailable') throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
      if (actions.reschedule !== 'direct') throw new AppError('NOT_ALLOWED', { action: actions.reschedule });

      const calendar = await loadCalendar(reader, deps.db, booking.data.slug);
      if (!calendar) throw new AppError('NOT_FOUND');
      await readCalendarLock(tx, deps.db, booking.data.ownerUid);
      const check = await checkSlot(reader, deps.db, calendar, startsAt, bookingOffer(booking.data), now, {
        excludeBookingId: booking.id
      });
      if (!check.free) return { status: 'slotTaken' as const, alternatives: check.alternatives.map(iso) };

      const endsAt = startsAt + booking.data.durationMinutes * 60_000;
      tx.update(booking.ref, {
        startsAt: ts(startsAt),
        endsAt: ts(endsAt),
        purgeAt: ts(purgeAtFor(endsAt)),
        rescheduleCount: booking.data.rescheduleCount + 1,
        clientConfirmedAt: FieldValue.delete(),
        lateByMinutes: FieldValue.delete(),
        lateReportedAt: FieldValue.delete(),
        reminderSentAt: FieldValue.delete(),
        lastClientAction: { kind: 'rescheduled', at: ts(now) },
        updatedAt: ts(now)
      });
      bumpCalendarLock(tx, deps.db, booking.data.ownerUid);
      return {
        status: 'moved' as const,
        startsAt: iso(startsAt),
        endsAt: iso(endsAt),
        rescheduleCount: booking.data.rescheduleCount + 1
      };
    });
  }
});
