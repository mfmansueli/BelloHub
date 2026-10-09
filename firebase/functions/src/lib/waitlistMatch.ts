import type { Deps } from '../app/Deps.js';
import type { BookingDoc, PublicProfileDoc, WaitlistDoc } from './docs.js';
import { dataOf, refs } from './store.js';
import { localDateOf } from './time.js';

/**
 * Who on the waitlist a freed time can go to: first come, first served among people still waiting, whose days include the
 * freed day and whose service fits in the freed minutes. A mirror of the iOS `WaitlistMatcher`
 * (BelloHub/Models/Agenda/WaitlistMatcher.swift): same three conditions, same order.
 */
export function matchesWaitlist(
  entries: readonly (WaitlistDoc & { id: string })[],
  freedDay: string,
  freedMinutes: number,
  serviceMinutes: ReadonlyMap<string, number>
): (WaitlistDoc & { id: string })[] {
  return entries
    .filter((entry) => {
      if (entry.status !== 'waiting' || freedDay < entry.dayFrom || freedDay > entry.dayTo) return false;
      if (!entry.serviceId) return true;
      const needed = serviceMinutes.get(entry.serviceId);
      return needed === undefined || needed <= freedMinutes;
    })
    .sort((a, b) => a.createdAt.toMillis() - b.createdAt.toMillis() || a.id.localeCompare(b.id));
}

/** The waiting entries a cancelled booking's freed time could serve (empty when nobody waits). */
export async function waitlistMatchesFor(deps: Deps, booking: BookingDoc): Promise<(WaitlistDoc & { id: string })[]> {
  const r = refs(deps.db);
  const waiting = await r.waitlist().where('ownerUid', '==', booking.ownerUid).where('status', '==', 'waiting').get();
  if (waiting.empty) return [];
  const profile = dataOf<PublicProfileDoc>(await r.profile(booking.slug).get());
  const serviceMinutes = new Map((profile?.services ?? []).map((service) => [service.id, service.durationMinutes]));
  const entries = waiting.docs.map((doc) => ({ id: doc.id, ...(doc.data() as WaitlistDoc) }));
  return matchesWaitlist(entries, localDateOf(booking.startsAt.toMillis(), booking.timeZoneID), booking.durationMinutes, serviceMinutes);
}
