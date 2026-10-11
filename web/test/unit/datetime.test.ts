import { describe, expect, it } from 'vitest';

import {
  addDays,
  addMonths,
  dayBounds,
  daysInMonth,
  deviceClockDiffers,
  instantFromZoned,
  monthBounds,
  monthGrid,
  offsetMinutes,
  regionClock,
  toDateKey,
  weekdayOf,
  zonedDateKey,
  zonedParts,
} from '../../src/lib/datetime';

// Dates below are hand-checked against the published rules of each zone (2026 DST changes: Europe on
// Sunday 29 March and Sunday 25 October, United States on Sunday 8 March and Sunday 1 November). Brazil and
// Mexico have no DST since 2019 and 2022.

const ms = (iso: string): number => Date.parse(iso);

describe('zonedParts and offsetMinutes', () => {
  it('reads the wall clock of the business zone, not the device zone', () => {
    // 2026-10-01T18:00:00Z is 15:00 in São Paulo (UTC-3).
    expect(zonedParts(ms('2026-10-01T18:00:00Z'), 'America/Sao_Paulo')).toEqual({
      year: 2026, month: 10, day: 1, hour: 15, minute: 0, weekday: 4,
    });
    expect(zonedParts(ms('2026-10-01T18:00:00Z'), 'Europe/Lisbon')).toMatchObject({ hour: 19, day: 1 });
  });

  it('shows midnight as hour 0, never 24', () => {
    expect(zonedParts(ms('2026-10-02T03:00:00Z'), 'America/Sao_Paulo')).toMatchObject({ day: 2, hour: 0, minute: 0 });
  });

  it('follows DST in Europe/Lisbon, Madrid, Rome, Berlin, London and New York', () => {
    expect(offsetMinutes(ms('2026-03-29T00:59:00Z'), 'Europe/Lisbon')).toBe(0);
    expect(offsetMinutes(ms('2026-03-29T01:00:00Z'), 'Europe/Lisbon')).toBe(60);
    expect(offsetMinutes(ms('2026-03-29T00:59:00Z'), 'Europe/Madrid')).toBe(60);
    expect(offsetMinutes(ms('2026-03-29T01:00:00Z'), 'Europe/Madrid')).toBe(120);
    expect(offsetMinutes(ms('2026-10-25T00:59:00Z'), 'Europe/Rome')).toBe(120);
    expect(offsetMinutes(ms('2026-10-25T01:00:00Z'), 'Europe/Rome')).toBe(60);
    expect(offsetMinutes(ms('2026-10-25T01:00:00Z'), 'Europe/Berlin')).toBe(60);
    expect(offsetMinutes(ms('2026-07-01T12:00:00Z'), 'Europe/London')).toBe(60);
    expect(offsetMinutes(ms('2026-01-01T12:00:00Z'), 'Europe/London')).toBe(0);
    expect(offsetMinutes(ms('2026-03-08T06:59:00Z'), 'America/New_York')).toBe(-300);
    expect(offsetMinutes(ms('2026-03-08T07:00:00Z'), 'America/New_York')).toBe(-240);
  });

  it('has no DST in São Paulo, Mexico City, Istanbul, Riyadh and Kolkata', () => {
    expect(offsetMinutes(ms('2026-01-15T12:00:00Z'), 'America/Sao_Paulo')).toBe(-180);
    expect(offsetMinutes(ms('2026-07-15T12:00:00Z'), 'America/Sao_Paulo')).toBe(-180);
    expect(offsetMinutes(ms('2026-07-15T12:00:00Z'), 'America/Mexico_City')).toBe(-360);
    expect(offsetMinutes(ms('2026-07-15T12:00:00Z'), 'Europe/Istanbul')).toBe(180);
    expect(offsetMinutes(ms('2026-07-15T12:00:00Z'), 'Asia/Riyadh')).toBe(180);
    expect(offsetMinutes(ms('2026-07-15T12:00:00Z'), 'Asia/Kolkata')).toBe(330);
  });
});

describe('instantFromZoned and day bounds', () => {
  it('turns a wall-clock time in the business zone into the right instant', () => {
    expect(new Date(instantFromZoned('2026-10-01', 15, 0, 'America/Sao_Paulo')).toISOString()).toBe('2026-10-01T18:00:00.000Z');
    expect(new Date(instantFromZoned('2026-07-01', 15, 0, 'Europe/Lisbon')).toISOString()).toBe('2026-07-01T14:00:00.000Z');
  });

  it('a day is 23 hours long when the clocks go forward and 25 when they go back', () => {
    const spring = dayBounds('2026-03-29', 'Europe/Lisbon');
    expect((spring.end - spring.start) / 3_600_000).toBe(23);
    const autumn = dayBounds('2026-10-25', 'Europe/Lisbon');
    expect((autumn.end - autumn.start) / 3_600_000).toBe(25);
    const plain = dayBounds('2026-10-01', 'America/Sao_Paulo');
    expect((plain.end - plain.start) / 3_600_000).toBe(24);
  });

  it('puts an evening slot on the right civil day even when UTC is already the next day', () => {
    // 22:30 in São Paulo on Oct 1 is 01:30 UTC on Oct 2.
    expect(zonedDateKey(ms('2026-10-02T01:30:00Z'), 'America/Sao_Paulo')).toBe('2026-10-01');
    expect(zonedDateKey(ms('2026-10-02T01:30:00Z'), 'Asia/Kolkata')).toBe('2026-10-02');
  });

  it('month bounds cover the whole civil month in the business zone', () => {
    const bounds = monthBounds(2026, 10, 'Europe/Lisbon');
    expect(new Date(bounds.start).toISOString()).toBe('2026-09-30T23:00:00.000Z');
    // 25 October is the end of summer time: the month's last midnight is at UTC+0.
    expect(new Date(bounds.end).toISOString()).toBe('2026-11-01T00:00:00.000Z');
  });
});

describe('civil date arithmetic', () => {
  it('adds days across months, years and leap days', () => {
    expect(addDays('2026-10-31', 1)).toBe('2026-11-01');
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
    expect(addDays('2028-02-28', 1)).toBe('2028-02-29');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
  });

  it('adds months and knows the length of each', () => {
    expect(addMonths(2026, 12, 1)).toEqual({ year: 2027, month: 1 });
    expect(addMonths(2026, 1, -1)).toEqual({ year: 2025, month: 12 });
    expect(daysInMonth(2026, 2)).toBe(28);
    expect(daysInMonth(2028, 2)).toBe(29);
    expect(daysInMonth(2026, 10)).toBe(31);
    expect(toDateKey(2026, 3, 5)).toBe('2026-03-05');
    expect(weekdayOf(2026, 10, 1)).toBe(4);
  });
});

describe('monthGrid', () => {
  it('October 2026 starts on a Thursday: four blanks on a Sunday-first grid, three on a Monday-first grid', () => {
    const sunday = monthGrid(2026, 10, 0);
    expect(sunday[0]).toEqual([null, null, null, null, 1, 2, 3]);
    expect(sunday.at(-1)?.filter((cell) => cell !== null).at(-1)).toBe(31);
    const monday = monthGrid(2026, 10, 1);
    expect(monday[0]).toEqual([null, null, null, 1, 2, 3, 4]);
  });

  it('always has full weeks and every day exactly once', () => {
    for (const firstDay of [0, 1, 6]) {
      for (let month = 1; month <= 12; month += 1) {
        const rows = monthGrid(2026, month, firstDay);
        expect(rows.every((row) => row.length === 7)).toBe(true);
        const days = rows.flat().filter((cell): cell is number => cell !== null);
        expect(days).toEqual(Array.from({ length: daysInMonth(2026, month) }, (_, i) => i + 1));
      }
    }
  });
});

describe('deviceClockDiffers', () => {
  it('is false for the same zone or the same offset that day, true otherwise', () => {
    const instant = ms('2026-10-01T18:00:00Z');
    expect(deviceClockDiffers(instant, 'America/Sao_Paulo', 'America/Sao_Paulo')).toBe(false);
    expect(deviceClockDiffers(instant, 'America/Sao_Paulo', 'America/Argentina/Buenos_Aires')).toBe(false);
    expect(deviceClockDiffers(instant, 'America/Sao_Paulo', 'Europe/Lisbon')).toBe(true);
    expect(deviceClockDiffers(instant, 'America/Sao_Paulo', null)).toBe(false);
  });
});

describe('regionClock (week start and clock follow the business region, D25)', () => {
  it('matches the documented defaults of docs/07 section 2.4', () => {
    const expected: Record<string, { firstDay: number; hourCycle: 'h23' | 'h12' }> = {
      US: { firstDay: 0, hourCycle: 'h12' },
      BR: { firstDay: 0, hourCycle: 'h23' },
      MX: { firstDay: 0, hourCycle: 'h12' },
      ES: { firstDay: 1, hourCycle: 'h23' },
      PT: { firstDay: 0, hourCycle: 'h23' },
      DE: { firstDay: 1, hourCycle: 'h23' },
      FR: { firstDay: 1, hourCycle: 'h23' },
      IT: { firstDay: 1, hourCycle: 'h23' },
      GB: { firstDay: 1, hourCycle: 'h23' },
    };
    for (const [region, rule] of Object.entries(expected)) {
      expect(regionClock(region), region).toEqual(rule);
    }
  });

  it('keeps the region even for a language the browser has no region data for', () => {
    // Saudi Arabia is a 12-hour region in the browser's data, the Emirates too: the point is that it resolves.
    expect(['h12', 'h23']).toContain(regionClock('SA').hourCycle);
    expect(regionClock('SA').firstDay).toBeGreaterThanOrEqual(0);
    expect(regionClock('ZZ').firstDay).toBeGreaterThanOrEqual(0);
  });
});
