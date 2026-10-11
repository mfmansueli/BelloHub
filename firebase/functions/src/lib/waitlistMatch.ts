import type { Deps } from '../app/Deps.js';
import { bookingOffer, loadCalendar, loadOccupied, planOn, timingOf } from './calendar.js';
import type { BookingDoc, WaitlistDoc } from './docs.js';
import { plainReader, refs } from './store.js';
import { localDateOf } from './time.js';

const MINUTE_MS = 60_000;
const DAY_MS = 86_400_000;

/**
 * Who on the waitlist a freed time can go to: first come, first served among people still waiting, whose days include the
 * freed day and whose service has a free start that uses the freed time (D56: the same smart-slot rule the page uses, so
 * extra time, processing time and the buffer all count). A mirror of the iOS `WaitlistMatcher`
 * (BelloHub/Models/Agenda/WaitlistMatcher.swift): same three conditions, same order. A service missing from `serviceFits`
 * (removed from the page, or no service named) does not stop a match.
 */
export function matchesWaitlist(
  entries: readonly (WaitlistDoc & { id: string })[],
  freedDay: string,
  serviceFits: ReadonlyMap<string, boolean>
): (WaitlistDoc & { id: string })[] {
  return entries
    .filter((entry) => {
      if (entry.status !== 'waiting' || freedDay < entry.dayFrom || freedDay > entry.dayTo) return false;
      if (!entry.serviceId) return true;
      return serviceFits.get(entry.serviceId) ?? true;
    })
    .sort((a, b) => a.createdAt.toMillis() - b.createdAt.toMillis() || a.id.localeCompare(b.id));
}

/** The waiting entries a cancelled booking's freed time could serve (empty when nobody waits). */
export async function waitlistMatchesFor(deps: Deps, booking: BookingDoc): Promise<(WaitlistDoc & { id: string })[]> {
  const r = refs(deps.db);
  const waiting = await r.waitlist().where('ownerUid', '==', booking.ownerUid).where('status', '==', 'waiting').get();
  if (waiting.empty) return [];
  const entries = waiting.docs.map((doc) => ({ id: doc.id, ...(doc.data() as WaitlistDoc) }));
  const freedDay = localDateOf(booking.startsAt.toMillis(), booking.timeZoneID);
  return matchesWaitlist(entries, freedDay, await serviceFitsFreedTime(deps, booking, entries));
}

/**
 * For each service people wait for: does it now have a free start whose blocked stretch overlaps the freed one? The
 * cancelled booking no longer occupies time, so this is exactly "the freed time makes room for it".
 */
async function serviceFitsFreedTime(
  deps: Deps,
  booking: BookingDoc,
  entries: readonly WaitlistDoc[]
): Promise<Map<string, boolean>> {
  const fits = new Map<string, boolean>();
  const calendar = await loadCalendar(plainReader, deps.db, booking.slug);
  if (!calendar) return fits;
  const now = deps.now();
  const freedTiming = bookingOffer(booking).timing;
  const freed = {
    start: booking.startsAt.toMillis() - freedTiming.prepMinutes * MINUTE_MS,
    end: booking.endsAt.toMillis() + freedTiming.cleanupMinutes * MINUTE_MS
  };
  const occupied = await loadOccupied(plainReader, deps.db, calendar, { start: freed.start - DAY_MS, end: freed.end + DAY_MS }, now);
  const day = localDateOf(booking.startsAt.toMillis(), booking.timeZoneID);
  for (const serviceId of new Set(entries.map((entry) => entry.serviceId).filter((id): id is string => !!id))) {
    const service = calendar.profile.services.find((candidate) => candidate.id === serviceId);
    if (!service) continue;
    const timing = timingOf(service);
    const starts = planOn(calendar, day, { durationMinutes: service.durationMinutes, timing }, now, occupied).all;
    fits.set(
      serviceId,
      starts.some((start) => {
        const from = start - timing.prepMinutes * MINUTE_MS;
        const to = start + (service.durationMinutes + timing.cleanupMinutes) * MINUTE_MS;
        return from < freed.end && to > freed.start;
      })
    );
  }
  return fits;
}
