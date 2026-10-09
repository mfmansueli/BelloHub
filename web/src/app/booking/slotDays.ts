// Free slots arrive as a flat list of instants; the pages show them day by day, in the professional's time zone
// (a slot at 23:30 in Lisbon is still that Lisbon day for a client in Sao Paulo).

import { zonedDateKey, type DateKey } from '../../lib/datetime';

/** Groups ISO instants by their calendar day in `timeZone`, days and times in ascending order. */
export function groupByDay(slots: readonly string[], timeZone: string): Map<DateKey, string[]> {
  const byDay = new Map<DateKey, string[]>();
  for (const slot of [...slots].sort()) {
    const day = zonedDateKey(Date.parse(slot), timeZone);
    byDay.set(day, [...(byDay.get(day) ?? []), slot]);
  }
  return byDay;
}
