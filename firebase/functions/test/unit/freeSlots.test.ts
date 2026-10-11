import { describe, expect, it } from 'vitest';

import { planSlots } from '../../src/lib/freeSlots.js';
import { loadRulesFixture } from '../support/fixture.js';

const fixture = loadRulesFixture();

describe('freeSlots mirrors the iOS FreeSlotsCalculator', () => {
  it('uses the same 15 minute grid as the iOS default', () => {
    expect(fixture.slotStepMinutes).toBe(15);
  });

  it('has the DST and ordinary cases of the Swift tests', () => {
    // A guard that the fixture is not accidentally empty after a regeneration.
    expect(fixture.freeSlots.length).toBeGreaterThan(80);
  });

  it('has the D56 smart-slot cases (anchors, extra time, processing, compact day)', () => {
    expect(fixture.freeSlots.filter((test) => test.name.startsWith('D56')).length).toBeGreaterThan(30);
    expect(fixture.freeSlots.some((test) => test.recommended.length < test.expected.length)).toBe(true);
  });

  describe.each(fixture.freeSlots)('$name', ({ input, expected, recommended }) => {
    it('offers exactly the starts the Swift code offers, and recommends the same ones', () => {
      const plan = planSlots({
        day: input.day,
        durationMinutes: input.durationMinutes,
        now: Date.parse(input.now),
        settings: input.settings,
        appointments: input.appointments.map(([start, end, timing]) => ({ start: Date.parse(start), end: Date.parse(end), timing })),
        blocks: input.blocks.map(([start, end]) => ({ start: Date.parse(start), end: Date.parse(end) })),
        stepMinutes: input.stepMinutes,
        timing: input.timing,
        compact: input.compact,
        shortestOfferMinutes: input.shortestOfferMinutes
      });
      const iso = (values: number[]): string[] => values.map((ms) => new Date(ms).toISOString());
      expect(iso(plan.all)).toEqual(expected);
      expect(iso(plan.recommended)).toEqual(recommended);
    });
  });
});
