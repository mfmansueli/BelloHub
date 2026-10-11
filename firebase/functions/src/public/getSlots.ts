import { defineUseCase } from '../app/UseCase.js';
import { MAX_RANGE_DAYS, RATE } from '../config/limits.js';
import * as contract from '../contracts/public.js';
import { findBookingByToken } from '../lib/bookingAccess.js';
import type { SlotOffer } from '../lib/calendar.js';
import { bookingOffer, loadCalendar, loadOccupied, planOn, resolveOffer, slotSettings } from '../lib/calendar.js';
import { AppError } from '../lib/errors.js';
import { holdKeyHash } from '../lib/holds.js';
import { consumeRate } from '../lib/rateLimit.js';
import { plainReader, ms } from '../lib/store.js';
import { addDays, daysBetween, instantAtLocal } from '../lib/time.js';

/** Free start times for a service, add-ons and guests, computed on the server from what she published (docs/10 section 3). */
export const getSlots = defineUseCase({
  name: 'getSlots',
  access: 'public',
  ...contract.getSlots,
  async handle(deps, input, ctx) {
    const now = deps.now();
    await consumeRate(deps, 'slots', ctx.ipHash, RATE.slotsIp);

    const days = daysBetween(input.from, input.to);
    if (days < 0 || days + 1 > MAX_RANGE_DAYS) throw new AppError('INVALID_ARGUMENT', { fields: ['to'] });

    const calendar = await loadCalendar(plainReader, deps.db, input.slug);
    if (!calendar) throw new AppError('NOT_FOUND');

    // Moving an existing booking: its own time does not block it, and its own duration is used. A page pause does
    // not stop a client from moving a visit she already has ("Their booked visits are not touched", D15).
    let offer: SlotOffer;
    let excludeBookingId: string | undefined;
    let pausedPage = false;
    if (input.rescheduleToken) {
      const booking = await findBookingByToken(plainReader, deps.db, input.rescheduleToken, now);
      if (booking.data.ownerUid !== calendar.ownerUid) throw new AppError('NOT_FOUND');
      offer = bookingOffer(booking.data);
      excludeBookingId = booking.id;
    } else {
      offer = resolveOffer(calendar.profile, input);
      const pausedUntil = calendar.profile.booking.pausedUntil;
      pausedPage = !calendar.profile.booking.acceptingBookings || (pausedUntil !== undefined && ms(pausedUntil) > now);
    }

    const { durationMinutes } = offer;
    const settings = slotSettings(calendar);
    const dates: string[] = [];
    for (let date = input.from; date <= input.to; date = addDays(date, 1)) dates.push(date);
    if (!settings || pausedPage) {
      return {
        timeZoneID: settings?.timeZoneID ?? calendar.profile.timeZoneID,
        durationMinutes,
        paused: pausedPage,
        days: dates.map((date) => ({ date, slots: [] }))
      };
    }

    const occupied = await loadOccupied(
      plainReader,
      deps.db,
      calendar,
      {
        start: instantAtLocal(input.from, 0, settings.timeZoneID),
        end: instantAtLocal(addDays(input.to, 1), 0, settings.timeZoneID)
      },
      now,
      { excludeBookingId, ownHoldKeyHash: input.holdKey ? holdKeyHash(input.holdKey) : undefined }
    );
    return {
      timeZoneID: settings.timeZoneID,
      durationMinutes,
      paused: false,
      // D56: `slots` are shown first; `more` (the other free starts) sits behind "Show all times".
      days: dates.map((date) => {
        const plan = planOn(calendar, date, offer, now, occupied);
        const shown = new Set(plan.recommended);
        const more = plan.all.filter((start) => !shown.has(start));
        return {
          date,
          slots: plan.recommended.map(isoOf),
          ...(more.length > 0 ? { more: more.map(isoOf) } : {})
        };
      })
    };
  }
});

function isoOf(start: number): string {
  return new Date(start).toISOString();
}
