import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import { cancelMode, freeUntil, lateCancelCountsAgainst, rescheduleMode, reschedulesLeft, type PolicyValues } from '../../src/lib/policy';

interface Case {
  name: string;
  policy: Partial<PolicyValues>;
  startsAt: string;
  now: string;
  rescheduleCount: number;
  expect: { freeUntil: string; cancel: string; reschedule: string; reschedulesLeft: number | null };
}

const fixture = JSON.parse(readFileSync(new URL('../fixtures/policy-cases.json', import.meta.url), 'utf8')) as {
  defaults: PolicyValues;
  cases: Case[];
};

describe('cancellation and reschedule rules (shared table, docs/11 section 4)', () => {
  for (const item of fixture.cases) {
    it(item.name, () => {
      const policy: PolicyValues = { ...fixture.defaults, ...item.policy };
      const startsAt = Date.parse(item.startsAt);
      const now = Date.parse(item.now);
      expect(new Date(freeUntil(startsAt, policy)).toISOString()).toBe(new Date(item.expect.freeUntil).toISOString());
      expect(cancelMode(startsAt, policy, now)).toBe(item.expect.cancel);
      expect(rescheduleMode(startsAt, policy, now, item.rescheduleCount)).toBe(item.expect.reschedule);
      expect(reschedulesLeft(policy, item.rescheduleCount)).toBe(item.expect.reschedulesLeft);
    });
  }

  it('a late cancellation counts against her only when no-show protection says so', () => {
    const base = fixture.defaults;
    expect(lateCancelCountsAgainst('allowLate', { ...base, lateCancelCounts: true })).toBe(true);
    expect(lateCancelCountsAgainst('allowLate', { ...base, lateCancelCounts: false })).toBe(false);
    expect(lateCancelCountsAgainst('free', { ...base, lateCancelCounts: true })).toBe(false);
    expect(lateCancelCountsAgainst('message', { ...base, lateCancelCounts: true })).toBe(false);
  });
});
