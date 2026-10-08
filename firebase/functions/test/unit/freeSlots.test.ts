import { describe, expect, it } from 'vitest';

import { freeSlots } from '../../src/lib/freeSlots.js';
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

  describe.each(fixture.freeSlots)('$name', ({ input, expected }) => {
    it('offers exactly the starts the Swift code offers', () => {
      const result = freeSlots({
        day: input.day,
        durationMinutes: input.durationMinutes,
        now: Date.parse(input.now),
        settings: input.settings,
        appointments: input.appointments.map(([start, end]) => ({ start: Date.parse(start), end: Date.parse(end) })),
        blocks: input.blocks.map(([start, end]) => ({ start: Date.parse(start), end: Date.parse(end) })),
        stepMinutes: input.stepMinutes
      }).map((ms) => new Date(ms).toISOString());
      expect(result).toEqual(expected);
    });
  });
});
