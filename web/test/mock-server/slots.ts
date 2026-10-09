// Free start times, the way the server computes them (docs/10 section 3): working windows in the professional's
// time zone, a lunch break, a buffer between visits, a minimum notice and a horizon, and everything already booked
// or held by someone else. Tuesday to Saturday, 09:00 to 12:30 and 13:30 to 19:00, starts every 30 minutes.

import { addDays, instantFromZoned, zonedDateKey, weekdayOf, parseDateKey, type DateKey } from '../../src/lib/datetime';

const MINUTE = 60_000;
const WINDOWS: readonly [number, number][] = [
  [9 * 60, 12 * 60 + 30],
  [13 * 60 + 30, 19 * 60],
];
const WORKING_DAYS = new Set([2, 3, 4, 5, 6]);

export interface Busy {
  readonly startsAt: number;
  readonly endsAt: number;
  /** Holds of the same session never block themselves. */
  readonly holdKey?: string;
  readonly bookingId?: string;
}

export interface SlotRules {
  readonly timeZone: string;
  readonly bufferMinutes: number;
  readonly minNoticeHours: number;
  readonly maxDaysAhead: number;
  readonly stepMinutes: number;
}

export const DEFAULT_RULES: Omit<SlotRules, 'timeZone'> = { bufferMinutes: 15, minNoticeHours: 2, maxDaysAhead: 60, stepMinutes: 30 };

export function overlaps(a: { startsAt: number; endsAt: number }, b: { startsAt: number; endsAt: number }, bufferMs: number): boolean {
  return a.startsAt < b.endsAt + bufferMs && b.startsAt < a.endsAt + bufferMs;
}

export function isFree(start: number, durationMinutes: number, rules: SlotRules, busy: readonly Busy[], now: number, ignore?: { holdKey?: string; bookingId?: string }): boolean {
  const end = start + durationMinutes * MINUTE;
  if (start < now + rules.minNoticeHours * 3_600_000) return false;
  if (start > now + rules.maxDaysAhead * 24 * 3_600_000) return false;
  const day = zonedDateKey(start, rules.timeZone);
  const { year, month, day: d } = parseDateKey(day);
  if (!WORKING_DAYS.has(weekdayOf(year, month, d))) return false;
  const inWindow = WINDOWS.some(([from, to]) => start >= instantFromZoned(day, Math.floor(from / 60), from % 60, rules.timeZone) && end <= instantFromZoned(day, Math.floor(to / 60), to % 60, rules.timeZone));
  if (!inWindow) return false;
  return !busy.some((item) => {
    if (ignore?.holdKey !== undefined && item.holdKey === ignore.holdKey) return false;
    if (ignore?.bookingId !== undefined && item.bookingId === ignore.bookingId) return false;
    return overlaps({ startsAt: start, endsAt: end }, item, rules.bufferMinutes * MINUTE);
  });
}

/** Free start times in `[from, to)`, as UTC ISO strings, ascending. */
export function freeSlots(from: number, to: number, durationMinutes: number, rules: SlotRules, busy: readonly Busy[], now: number, ignore?: { holdKey?: string; bookingId?: string }): string[] {
  const out: string[] = [];
  let day: DateKey = addDays(zonedDateKey(from, rules.timeZone), -1);
  const last = addDays(zonedDateKey(to, rules.timeZone), 1);
  while (day <= last) {
    for (const [windowStart, windowEnd] of WINDOWS) {
      for (let minute = windowStart; minute + durationMinutes <= windowEnd; minute += rules.stepMinutes) {
        const start = instantFromZoned(day, Math.floor(minute / 60), minute % 60, rules.timeZone);
        if (start >= from && start < to && isFree(start, durationMinutes, rules, busy, now, ignore)) out.push(new Date(start).toISOString());
      }
    }
    day = addDays(day, 1);
  }
  return out;
}
