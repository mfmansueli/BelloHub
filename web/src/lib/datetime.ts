// Civil dates and time zones, without a date library. Appointments are UTC instants plus the business
// `timeZoneID`; the page renders in the business zone (docs/05-DATA-MODEL.md section 2, docs/10 section 3).
// Everything takes the zone as a parameter and `now` from the caller, so it is testable.

export interface ZonedParts {
  readonly year: number;
  /** 1 to 12. */
  readonly month: number;
  readonly day: number;
  readonly hour: number;
  readonly minute: number;
  /** 0 = Sunday. */
  readonly weekday: number;
}

/** A calendar date with no time zone, `YYYY-MM-DD`. */
export type DateKey = string;

const partsFormatters = new Map<string, Intl.DateTimeFormat>();

function partsFormatter(timeZone: string): Intl.DateTimeFormat {
  let formatter = partsFormatters.get(timeZone);
  if (formatter === undefined) {
    formatter = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hourCycle: 'h23',
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
    });
    partsFormatters.set(timeZone, formatter);
  }
  return formatter;
}

export function isValidTimeZone(timeZone: string): boolean {
  try {
    partsFormatter(timeZone);
    return true;
  } catch {
    return false;
  }
}

function pad(value: number, length = 2): string {
  return String(value).padStart(length, '0');
}

export function weekdayOf(year: number, month: number, day: number): number {
  return new Date(Date.UTC(year, month - 1, day)).getUTCDay();
}

/** The wall-clock fields of an instant in `timeZone`. */
export function zonedParts(instant: number | Date, timeZone: string): ZonedParts {
  const ms = typeof instant === 'number' ? instant : instant.getTime();
  const fields: Record<string, number> = {};
  for (const part of partsFormatter(timeZone).formatToParts(ms)) {
    if (part.type !== 'literal') fields[part.type] = Number(part.value);
  }
  const year = fields['year'] ?? 1970;
  const month = fields['month'] ?? 1;
  const day = fields['day'] ?? 1;
  return {
    year,
    month,
    day,
    hour: (fields['hour'] ?? 0) % 24,
    minute: fields['minute'] ?? 0,
    weekday: weekdayOf(year, month, day),
  };
}

export function toDateKey(year: number, month: number, day: number): DateKey {
  return `${pad(year, 4)}-${pad(month)}-${pad(day)}`;
}

export function parseDateKey(key: DateKey): { year: number; month: number; day: number } {
  const [year = 1970, month = 1, day = 1] = key.split('-').map(Number);
  return { year, month, day };
}

/** The civil date of an instant in `timeZone`. */
export function zonedDateKey(instant: number | Date, timeZone: string): DateKey {
  const parts = zonedParts(instant, timeZone);
  return toDateKey(parts.year, parts.month, parts.day);
}

/** Minutes east of UTC at `instant` in `timeZone` (São Paulo is -180). */
export function offsetMinutes(instant: number | Date, timeZone: string): number {
  const ms = typeof instant === 'number' ? instant : instant.getTime();
  const parts = zonedParts(ms, timeZone);
  const asUtc = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute);
  return Math.round((asUtc - Math.floor(ms / 60000) * 60000) / 60000);
}

/** The instant at which the wall clock of `timeZone` reads the given civil date and time. */
export function instantFromZoned(date: DateKey, hour: number, minute: number, timeZone: string): number {
  const { year, month, day } = parseDateKey(date);
  const wall = Date.UTC(year, month - 1, day, hour, minute);
  // The offset may differ between the guess and the answer around a DST change: iterate twice.
  let guess = wall - offsetMinutes(wall, timeZone) * 60000;
  guess = wall - offsetMinutes(guess, timeZone) * 60000;
  return guess;
}

export function addDays(date: DateKey, days: number): DateKey {
  const { year, month, day } = parseDateKey(date);
  const moved = new Date(Date.UTC(year, month - 1, day + days));
  return toDateKey(moved.getUTCFullYear(), moved.getUTCMonth() + 1, moved.getUTCDate());
}

export function addMonths(year: number, month: number, months: number): { year: number; month: number } {
  const index = year * 12 + (month - 1) + months;
  return { year: Math.floor(index / 12), month: (index % 12) + 1 };
}

export function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

export function compareDateKeys(a: DateKey, b: DateKey): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

/** `[start, end)` of a civil day in `timeZone` as UTC instants (a day can be 23 or 25 hours long). */
export function dayBounds(date: DateKey, timeZone: string): { start: number; end: number } {
  return { start: instantFromZoned(date, 0, 0, timeZone), end: instantFromZoned(addDays(date, 1), 0, 0, timeZone) };
}

/** `[start, end)` of a calendar month in `timeZone`. */
export function monthBounds(year: number, month: number, timeZone: string): { start: number; end: number } {
  const next = addMonths(year, month, 1);
  return {
    start: instantFromZoned(toDateKey(year, month, 1), 0, 0, timeZone),
    end: instantFromZoned(toDateKey(next.year, next.month, 1), 0, 0, timeZone),
  };
}

/**
 * Weeks of a month as rows of seven cells (null outside the month), starting on `firstDay` (0 = Sunday).
 * Civil dates only, so the grid is the same in every zone.
 */
export function monthGrid(year: number, month: number, firstDay: number): (number | null)[][] {
  const lead = (weekdayOf(year, month, 1) - firstDay + 7) % 7;
  const total = daysInMonth(year, month);
  const cells: (number | null)[] = [];
  for (let i = 0; i < lead; i += 1) cells.push(null);
  for (let day = 1; day <= total; day += 1) cells.push(day);
  while (cells.length % 7 !== 0) cells.push(null);
  const rows: (number | null)[][] = [];
  for (let i = 0; i < cells.length; i += 7) rows.push(cells.slice(i, i + 7));
  return rows;
}

/** The zone this device is in, or null when the browser hides it. */
export function deviceTimeZone(): string | null {
  try {
    return new Intl.DateTimeFormat().resolvedOptions().timeZone || null;
  } catch {
    return null;
  }
}

/**
 * True when the device clock at `instant` would read a different time than the business clock, which is when
 * the page warns that times are in the professional's zone (docs/10 section 3). Two zones with the same offset
 * on that day are the same for the client's purposes.
 */
export function deviceClockDiffers(instant: number, businessZone: string, deviceZone: string | null): boolean {
  if (deviceZone === null || deviceZone === businessZone) return false;
  return offsetMinutes(instant, deviceZone) !== offsetMinutes(instant, businessZone);
}

// MARK: - Region defaults (week start and clock follow the business region, D25)

export interface RegionClock {
  /** 0 = Sunday. */
  readonly firstDay: number;
  readonly hourCycle: 'h23' | 'h12';
}

/** Known first weekdays for the regions the product presets, used when `Intl.Locale.getWeekInfo` is missing. */
const FIRST_DAY_FALLBACK: Readonly<Record<string, number>> = {
  US: 0, BR: 0, MX: 0, PT: 0, CA: 0, AR: 0, CO: 0, PE: 0, CL: 1, ID: 0, IN: 0, SA: 0, AU: 1, NZ: 1, ZA: 0, ES: 1,
  IT: 1, FR: 1, DE: 1, AT: 1, CH: 1, GB: 1, IE: 1, TR: 1, AE: 6,
};

interface WeekInfoLocale extends Intl.Locale {
  getWeekInfo?: () => { firstDay: number };
  weekInfo?: { firstDay: number };
}

/** Week start and clock of a region, read from the browser's own data with a short fallback table. */
export function regionClock(regionCode: string): RegionClock {
  let locale = 'en-US';
  try {
    // The region's main language with the region, and no script subtag: browsers resolve `en-Latn-GB` to plain
    // `en` and lose the region, which is what decides the clock.
    locale = `${new Intl.Locale(`und-${regionCode}`).maximize().language}-${regionCode.toUpperCase()}`;
  } catch {
    // keep the default
  }
  let firstDay = FIRST_DAY_FALLBACK[regionCode.toUpperCase()] ?? 1;
  try {
    const info = new Intl.Locale(locale) as WeekInfoLocale;
    const reported = info.getWeekInfo?.().firstDay ?? info.weekInfo?.firstDay;
    if (reported !== undefined) firstDay = reported % 7;
  } catch {
    // keep the fallback
  }
  let hourCycle: 'h23' | 'h12' = 'h23';
  try {
    const cycle = new Intl.DateTimeFormat(locale, { hour: 'numeric' }).resolvedOptions().hourCycle;
    hourCycle = cycle === 'h11' || cycle === 'h12' ? 'h12' : 'h23';
  } catch {
    // keep the default
  }
  return { firstDay, hourCycle };
}
