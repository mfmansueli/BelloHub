import { describe, expect, it } from 'vitest';

import type { AvailabilitySettings, FreeSlotsRequest, TimedInterval, VisitTiming } from '../../src/lib/freeSlots.js';
import { MATCH_SERVICE_STEP, NO_EXTRA_TIME, planSlots } from '../../src/lib/freeSlots.js';
import { instantAtLocal } from '../../src/lib/time.js';

// D56 by hand: the expectations below were worked out on paper (docs/agent-notes/smart-slots.md has the timelines), so
// they check the rule itself; the shared fixture (freeSlots.test.ts) checks that Swift and TypeScript agree.

const ZONE = 'America/Sao_Paulo';
const DAY = '2026-10-08'; // a Thursday
const at = (hhmm: string): number => {
  const [hours, minutes] = hhmm.split(':').map(Number);
  return instantAtLocal(DAY, (hours ?? 0) * 60 + (minutes ?? 0), ZONE);
};
const clock = (instants: number[]): string[] =>
  instants.map((value) => new Date(value - 3 * 3_600_000).toISOString().slice(11, 16));

function morning(bufferMinutes = 10): AvailabilitySettings {
  return {
    weekly: [{ weekday: 5, startMinutes: 9 * 60, endMinutes: 13 * 60 }],
    breaks: [],
    daysOff: [],
    bufferMinutes,
    minNoticeHours: 0,
    maxDaysAhead: 60,
    timeZoneID: ZONE
  };
}

function plan(overrides: Partial<FreeSlotsRequest> & { durationMinutes: number }): { all: string[]; recommended: string[] } {
  const result = planSlots({
    day: DAY,
    now: Date.parse('2026-10-01T15:00:00Z'),
    settings: morning(),
    appointments: [],
    blocks: [],
    stepMinutes: 15,
    compact: true,
    shortestOfferMinutes: 30,
    ...overrides
  });
  return { all: clock(result.all), recommended: clock(result.recommended) };
}

const visit = (from: string, to: string, timing?: VisitTiming): TimedInterval => ({ start: at(from), end: at(to), timing });

describe('smart slots (D56)', () => {
  it('an empty morning offers every grid time and recommends the ones that leave no dead gap', () => {
    const result = plan({ durationMinutes: 75 });
    expect(result.all).toEqual(['09:00', '09:15', '09:30', '09:45', '10:00', '10:15', '10:30', '10:45', '11:00', '11:15', '11:30', '11:45']);
    expect(result.recommended).toEqual(['09:00', '09:45', '10:00', '10:15', '10:30', '10:45', '11:00', '11:45']);
  });

  it('anchors a 75 minute service right after a visit ending 10:05, even on a 30 minute grid', () => {
    const result = plan({ durationMinutes: 75, stepMinutes: 30, appointments: [visit('09:35', '10:05')] });
    expect(result.all).toEqual(['10:15', '10:30', '11:00', '11:30', '11:45']);
    expect(result.recommended).toEqual(['10:15', '11:00', '11:45']);
  });

  it('with two visits, keeps the gaps tight and falls back honestly where every time leaves a dead gap', () => {
    const result = plan({ durationMinutes: 30, appointments: [visit('09:30', '10:00'), visit('11:00', '12:15')] });
    expect(result.all).toEqual(['10:10', '10:15', '10:20', '12:25', '12:30']);
    // 10:15 leaves two slivers of 5 minutes; 10:10 and 10:20 leave one of 10. 12:25 and 12:30 are the only times left.
    expect(result.recommended).toEqual(['10:10', '10:20', '12:25', '12:30']);
  });

  it('shows every free start when the day is not kept compact', () => {
    const result = plan({ durationMinutes: 30, compact: false, appointments: [visit('09:30', '10:00'), visit('11:00', '12:15')] });
    expect(result.recommended).toEqual(result.all);
  });

  it('lets a visit sit inside another visit\'s processing time, without the buffer', () => {
    const colour: VisitTiming = { ...NO_EXTRA_TIME, processingStartMinutes: 30, processingMinutes: 45 };
    const result = plan({ durationMinutes: 30, appointments: [visit('09:00', '10:30', colour)] });
    expect(result.all.slice(0, 4)).toEqual(['09:30', '09:45', '10:40', '10:45']);
    expect(result.all.at(-1)).toBe('12:30');
  });

  it('keeps the inner visit\'s own prep inside the processing stretch', () => {
    const colour: VisitTiming = { ...NO_EXTRA_TIME, processingStartMinutes: 30, processingMinutes: 45 };
    const result = plan({
      durationMinutes: 30,
      timing: { ...NO_EXTRA_TIME, prepMinutes: 5 },
      appointments: [visit('09:00', '10:30', colour)]
    });
    expect(result.all.slice(0, 3)).toEqual(['09:35', '09:45', '10:45']);
  });

  it('blocks prep and clean-up around a visit without changing its visible start', () => {
    const result = plan({ durationMinutes: 30, timing: { ...NO_EXTRA_TIME, prepMinutes: 10, cleanupMinutes: 15 }, compact: false });
    expect(result.all[0]).toBe('09:10');
    expect(result.all.at(-1)).toBe('12:15');
  });

  it('a visit\'s clean-up keeps the next one away, plus the buffer', () => {
    const result = plan({ durationMinutes: 30, appointments: [visit('09:00', '09:30', { ...NO_EXTRA_TIME, cleanupMinutes: 15 })] });
    expect(result.all[0]).toBe('09:55');
  });

  it('"match the service" tiles the stretch with whole visits', () => {
    expect(plan({ durationMinutes: 75, stepMinutes: MATCH_SERVICE_STEP }).all).toEqual(['09:00', '10:25', '11:45']);
    const padded = plan({
      durationMinutes: 75,
      stepMinutes: MATCH_SERVICE_STEP,
      timing: { ...NO_EXTRA_TIME, prepMinutes: 5, cleanupMinutes: 5 }
    });
    expect(padded.all).toEqual(['09:05', '10:40', '11:40']);
  });

  it('rounds anchors inwards to the 5 minute clock', () => {
    const result = plan({ durationMinutes: 30, stepMinutes: 60, compact: false, appointments: [visit('09:00', '09:33')] });
    expect(result.all[0]).toBe('09:45');
  });

  it('never recommends anything when nothing is free', () => {
    const result = plan({ durationMinutes: 300 });
    expect(result).toEqual({ all: [], recommended: [] });
  });
});
