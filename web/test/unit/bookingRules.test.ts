import { describe, expect, it } from 'vitest';

import { bookingRules } from '../../src/lib/bookingRules';
import type { PolicyValues } from '../../src/lib/policy';

function makePolicy(extra: Partial<PolicyValues> = {}): PolicyValues {
  return {
    freeWindowHours: 24,
    clientCanReschedule: true,
    maxReschedules: 2,
    afterWindowCancel: 'allow',
    afterWindowReschedule: 'request',
    askConfirmation: true,
    graceMinutes: 15,
    ...extra,
  };
}

const keys = (policy: PolicyValues): string[] => bookingRules(policy).map((rule) => rule.key);

describe('the rules of a booking (D47)', () => {
  it('words every field of the published policy and nothing else', () => {
    expect(keys(makePolicy())).toEqual(['br.free', 'br.rescheduleLimit', 'br.afterRescheduleRequest', 'br.afterCancelAllow', 'br.confirm', 'br.late']);
    expect(bookingRules(makePolicy()).find((rule) => rule.key === 'br.rescheduleLimit')?.count).toBe(2);
  });

  it('follows the booking\'s policy: no rescheduling, cancel by message, no confirmation, no limit', () => {
    const policy = makePolicy({ clientCanReschedule: false, afterWindowCancel: 'message', askConfirmation: false, maxReschedules: undefined });
    expect(keys(policy)).toEqual(['br.free', 'br.noReschedule', 'br.afterCancelMessage', 'br.late']);
    expect(keys(makePolicy({ maxReschedules: undefined, afterWindowReschedule: 'message' }))).toContain('br.afterRescheduleMessage');
  });

  it('never claims that a late cancellation counts as missed unless the policy itself says so', () => {
    expect(keys(makePolicy())).not.toContain('br.lateCounts');
    expect(keys(makePolicy({ lateCancelCounts: false }))).not.toContain('br.lateCounts');
    expect(keys(makePolicy({ lateCancelCounts: true }))).toContain('br.lateCounts');
  });
});
