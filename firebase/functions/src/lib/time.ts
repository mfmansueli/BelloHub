// Time zone arithmetic without a library: Intl knows the offsets, we only need the three conversions the booking
// rules use (docs/05-DATA-MODEL.md "FreeSlots", the iOS FreeSlotsCalculator).
//
// The semantics were measured on Foundation (scripts/rules-fixtures) and are mirrored on purpose:
//  - a wall-clock time that does not exist (spring forward) becomes the first valid instant after the gap;
//  - a wall-clock time that happens twice (fall back) means its first occurrence.

export type LocalDate = string;

const MINUTE_MS = 60_000;
const DAY_MS = 86_400_000;

const formatters = new Map<string, Intl.DateTimeFormat>();

function zoneFormatter(timeZone: string): Intl.DateTimeFormat {
  let formatter = formatters.get(timeZone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
    formatters.set(timeZone, formatter);
  }
  return formatter;
}

export function isValidTimeZone(timeZone: string): boolean {
  try {
    zoneFormatter(timeZone);
    return true;
  } catch {
    return false;
  }
}

interface LocalFields {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}

function localFields(ms: number, timeZone: string): LocalFields {
  const parts = zoneFormatter(timeZone).formatToParts(new Date(ms));
  const value = (type: Intl.DateTimeFormatPartTypes): number => {
    const part = parts.find((candidate) => candidate.type === type);
    return part ? Number(part.value) : 0;
  };
  return {
    year: value('year'),
    month: value('month'),
    day: value('day'),
    hour: value('hour'),
    minute: value('minute'),
    second: value('second')
  };
}

/** The UTC offset of `timeZone` at the instant `ms`, in minutes (positive east of Greenwich). */
export function offsetMinutesAt(ms: number, timeZone: string): number {
  const f = localFields(ms, timeZone);
  const wallAsUtc = Date.UTC(f.year, f.month - 1, f.day, f.hour, f.minute, f.second);
  return Math.round((wallAsUtc - Math.floor(ms / 1000) * 1000) / MINUTE_MS);
}

const LOCAL_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;

export function parseLocalDate(date: LocalDate): { year: number; month: number; day: number } | null {
  const match = LOCAL_DATE.exec(date);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const check = new Date(Date.UTC(year, month - 1, day));
  if (check.getUTCFullYear() !== year || check.getUTCMonth() !== month - 1 || check.getUTCDate() !== day) return null;
  return { year, month, day };
}

export function isLocalDate(value: string): boolean {
  return parseLocalDate(value) !== null;
}

function formatLocalDate(utcMidnightMs: number): LocalDate {
  return new Date(utcMidnightMs).toISOString().slice(0, 10);
}

/** The calendar day of `ms` in `timeZone`. */
export function localDateOf(ms: number, timeZone: string): LocalDate {
  const f = localFields(ms, timeZone);
  return formatLocalDate(Date.UTC(f.year, f.month - 1, f.day));
}

export function addDays(date: LocalDate, days: number): LocalDate {
  const parsed = parseLocalDate(date);
  if (!parsed) throw new RangeError('invalid local date');
  return formatLocalDate(Date.UTC(parsed.year, parsed.month - 1, parsed.day + days));
}

/** Whole days from `from` to `to` (negative when `to` is earlier). */
export function daysBetween(from: LocalDate, to: LocalDate): number {
  const a = parseLocalDate(from);
  const b = parseLocalDate(to);
  if (!a || !b) throw new RangeError('invalid local date');
  return Math.round((Date.UTC(b.year, b.month - 1, b.day) - Date.UTC(a.year, a.month - 1, a.day)) / DAY_MS);
}

/** 1 is Sunday and 7 is Saturday, as in the iOS `Calendar`. */
export function weekdayOf(date: LocalDate): number {
  const parsed = parseLocalDate(date);
  if (!parsed) throw new RangeError('invalid local date');
  return new Date(Date.UTC(parsed.year, parsed.month - 1, parsed.day)).getUTCDay() + 1;
}

/**
 * The instant at which the wall clock of `timeZone` reads `minutesFromMidnight` on `date`.
 * 1440 (midnight at the end of the day) is the start of the next day.
 */
export function instantAtLocal(date: LocalDate, minutesFromMidnight: number, timeZone: string): number {
  if (minutesFromMidnight >= 24 * 60) return instantAtLocal(addDays(date, 1), 0, timeZone);
  const parsed = parseLocalDate(date);
  if (!parsed) throw new RangeError('invalid local date');
  const naive = Date.UTC(parsed.year, parsed.month - 1, parsed.day, 0, minutesFromMidnight);
  const before = offsetMinutesAt(naive - DAY_MS, timeZone);
  const after = offsetMinutesAt(naive + DAY_MS, timeZone);

  // An instant is a valid reading of the wall time when the zone really has that offset there.
  const valid: number[] = [];
  for (const offset of new Set([before, after])) {
    const candidate = naive - offset * MINUTE_MS;
    if (offsetMinutesAt(candidate, timeZone) === offset) valid.push(candidate);
  }
  const first = valid.length > 0 ? Math.min(...valid) : undefined;
  if (first !== undefined) return first;

  // The wall time falls inside a gap: take the instant the clock jumps, found by bisection to the second.
  let low = Math.min(naive - before * MINUTE_MS, naive - after * MINUTE_MS);
  let high = Math.max(naive - before * MINUTE_MS, naive - after * MINUTE_MS);
  const offsetAfterGap = Math.max(before, after);
  while (high - low > 1000) {
    const middle = low + Math.ceil((high - low) / 2000) * 1000;
    if (offsetMinutesAt(middle, timeZone) === offsetAfterGap) high = middle;
    else low = middle;
  }
  return high;
}

export function startOfLocalDay(date: LocalDate, timeZone: string): number {
  return instantAtLocal(date, 0, timeZone);
}
