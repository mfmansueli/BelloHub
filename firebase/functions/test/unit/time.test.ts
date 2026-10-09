import { describe, expect, it } from 'vitest';

import {
  addDays,
  daysBetween,
  instantAtLocal,
  isLocalDate,
  isValidTimeZone,
  localDateOf,
  offsetMinutesAt,
  parseLocalDate,
  startOfLocalDay,
  weekdayOf
} from '../../src/lib/time.js';

const iso = (ms: number): string => new Date(ms).toISOString();

describe('time zone arithmetic', () => {
  it('knows offsets, including daylight saving', () => {
    expect(offsetMinutesAt(Date.UTC(2026, 0, 15, 12), 'Europe/Lisbon')).toBe(0);
    expect(offsetMinutesAt(Date.UTC(2026, 6, 15, 12), 'Europe/Lisbon')).toBe(60);
    expect(offsetMinutesAt(Date.UTC(2026, 9, 8, 12), 'America/Sao_Paulo')).toBe(-180);
    expect(offsetMinutesAt(Date.UTC(2026, 9, 8, 12), 'Asia/Kolkata')).toBe(330);
    expect(offsetMinutesAt(Date.UTC(2026, 9, 8, 12), 'Europe/Istanbul')).toBe(180);
  });

  it('converts a wall-clock time to an instant', () => {
    expect(iso(instantAtLocal('2026-10-08', 9 * 60, 'America/Sao_Paulo'))).toBe('2026-10-08T12:00:00.000Z');
    expect(iso(instantAtLocal('2026-10-08', 9 * 60, 'Europe/Lisbon'))).toBe('2026-10-08T08:00:00.000Z');
  });

  it('moves a time inside the spring-forward gap to the first valid instant', () => {
    // Lisbon, 2026-03-29: 01:00 WET jumps to 02:00 WEST, so 01:30 does not exist.
    expect(iso(instantAtLocal('2026-03-29', 90, 'Europe/Lisbon'))).toBe('2026-03-29T01:00:00.000Z');
    // New York, 2026-03-08: 02:00 EST jumps to 03:00 EDT.
    expect(iso(instantAtLocal('2026-03-08', 150, 'America/New_York'))).toBe('2026-03-08T07:00:00.000Z');
  });

  it('takes the first occurrence of a time that happens twice', () => {
    // Lisbon, 2026-10-25: 02:00 WEST falls back to 01:00 WET, so 01:30 happens twice.
    expect(iso(instantAtLocal('2026-10-25', 90, 'Europe/Lisbon'))).toBe('2026-10-25T00:30:00.000Z');
  });

  it('reads 1440 minutes as the start of the next day', () => {
    expect(iso(instantAtLocal('2026-10-08', 1440, 'America/Sao_Paulo'))).toBe('2026-10-09T03:00:00.000Z');
  });

  it('finds the business day of an instant, which is not the UTC day', () => {
    // 2026-10-09 01:00 UTC is still Thursday the 8th in Sao Paulo.
    expect(localDateOf(Date.UTC(2026, 9, 9, 1), 'America/Sao_Paulo')).toBe('2026-10-08');
    expect(localDateOf(Date.UTC(2026, 9, 9, 1), 'Europe/Lisbon')).toBe('2026-10-09');
  });

  it('starts the local day at midnight of that zone', () => {
    expect(iso(startOfLocalDay('2026-10-08', 'America/Sao_Paulo'))).toBe('2026-10-08T03:00:00.000Z');
  });

  it('validates time zones and local dates', () => {
    expect(isValidTimeZone('America/Sao_Paulo')).toBe(true);
    expect(isValidTimeZone('Mars/Olympus')).toBe(false);
    expect(isLocalDate('2026-02-29')).toBe(false);
    expect(isLocalDate('2026-02-28')).toBe(true);
    expect(isLocalDate('2026-2-8')).toBe(false);
    expect(parseLocalDate('nope')).toBeNull();
  });

  it('does local calendar arithmetic', () => {
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
    expect(daysBetween('2026-10-08', '2026-12-07')).toBe(60);
    expect(weekdayOf('2026-10-08')).toBe(5); // Thursday, 1 is Sunday
    expect(weekdayOf('2026-10-11')).toBe(1);
  });
});
