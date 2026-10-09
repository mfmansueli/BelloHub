import { describe, expect, it } from 'vitest';

import {
  approvalReason,
  bookingPhase,
  countedNoShows,
  decideCancellation,
  envelopeExpiresAt,
  intakeIsCurrent,
  isLateCancellation,
  isPausedFor,
  isPlanActive,
  purgeAtFor,
  registrationDecision,
  totalMinutes
} from '../../src/lib/rules.js';
import type { NoShowMark, NoShowPolicy } from '../../src/lib/rules.js';
import { loadRulesFixture } from '../support/fixture.js';

const fixture = loadRulesFixture();
const DAY = 86_400_000;

describe('cancellation rules mirror the iOS CancellationEvaluator', () => {
  it.each(fixture.cancellation)('$name', ({ policy, startsAt, now, rescheduleCount, expected }) => {
    const decision = decideCancellation(policy, Date.parse(startsAt), Date.parse(now), rescheduleCount);
    expect(decision.cancel).toBe(expected.cancel);
    expect(decision.reschedule).toBe(expected.reschedule);
    expect(decision.isInsideFreeWindow).toBe(expected.isInsideFreeWindow);
    expect(decision.cancellationWouldBeLate).toBe(expected.cancellationWouldBeLate);
    expect(decision.hoursUntilStart).toBeCloseTo(expected.hoursUntilStart, 6);
  });

  it.each(fixture.lateCancellation)('late cancellation: $name', ({ policy, startsAt, cancelledAt, expected }) => {
    expect(isLateCancellation(policy, Date.parse(startsAt), Date.parse(cancelledAt))).toBe(expected);
  });
});

describe('the free registrations mirror the iOS RegistrationQuota (D42)', () => {
  it.each(fixture.registrationQuota)(
    'ledger $ledgerCount server $serverCount plan $hasActivePlan new $forNewClients',
    (row) => {
      const used = Math.max(row.ledgerCount, row.serverCount ?? 0, 0);
      expect(used).toBe(row.expected.used);
      // The server decides one client at a time from the larger count; the iOS batch answer follows from it.
      const remaining = Math.max(10 - used, 0);
      expect(remaining).toBe(row.expected.remainingFree);
      const single = registrationDecision(used, row.hasActivePlan);
      if (row.forNewClients === 1) expect(single).toBe(row.expected.decision);
      if (row.expected.decision === 'allowed') expect(single).toBe('allowed');
      if (row.expected.decision === 'needsSubscription') expect(single).toBe('needsSubscription');
      if (row.expected.decision === 'allowedPartially') {
        expect(single).toBe('allowed');
        expect(row.expected.count).toBe(remaining);
      }
    }
  );

  it('allows the 10th and refuses the 11th', () => {
    expect(registrationDecision(9, false)).toBe('allowed');
    expect(registrationDecision(10, false)).toBe('needsSubscription');
    expect(registrationDecision(10, true)).toBe('allowed');
  });
});

describe('plan state', () => {
  const now = Date.UTC(2026, 9, 8);
  it('is active for active and grace states until they expire', () => {
    expect(isPlanActive({ state: 'active', expiresAt: now + DAY }, now)).toBe(true);
    expect(isPlanActive({ state: 'grace', expiresAt: now + DAY }, now)).toBe(true);
    expect(isPlanActive({ state: 'active', expiresAt: now - 1 }, now)).toBe(false);
    expect(isPlanActive({ state: 'expired', expiresAt: now + DAY }, now)).toBe(false);
    expect(isPlanActive({ state: 'revoked' }, now)).toBe(false);
    expect(isPlanActive({ state: 'none' }, now)).toBe(false);
    expect(isPlanActive(undefined, now)).toBe(false);
  });
});

describe('no-show counting (D13)', () => {
  const now = Date.UTC(2026, 9, 8, 12);
  const policy: NoShowPolicy = { isOn: true, limit: 3, action: 'approveNewBookings', lateCancelCounts: false, countingMonths: 12 };
  const mark = (id: string, daysAgo: number, kind: NoShowMark['kind'] = 'noShow'): NoShowMark => ({
    id,
    at: now - daysAgo * DAY,
    kind
  });

  it('counts marks inside the period and forgets older ones', () => {
    expect(countedNoShows(policy, [mark('a', 10), mark('b', 200), mark('c', 400)], undefined, now)).toBe(2);
  });

  it('counts late cancellations only when the policy says so', () => {
    const marks = [mark('a', 5, 'lateCancel'), mark('b', 6)];
    expect(countedNoShows(policy, marks, undefined, now)).toBe(1);
    expect(countedNoShows({ ...policy, lateCancelCounts: true }, marks, undefined, now)).toBe(2);
  });

  it('starts from zero after a reset and ignores everything when protection is off', () => {
    expect(countedNoShows(policy, [mark('a', 10), mark('b', 3)], now - 5 * DAY, now)).toBe(1);
    expect(countedNoShows({ ...policy, isOn: false }, [mark('a', 10)], undefined, now)).toBe(0);
  });

  it('uses the counting months of the policy', () => {
    expect(countedNoShows({ ...policy, countingMonths: 3 }, [mark('a', 60), mark('b', 120)], undefined, now)).toBe(1);
  });
});

describe('who waits for approval (D13, D15, D42)', () => {
  const base = {
    confirmNewClients: false,
    isNewClient: true,
    registrationCount: 3,
    planActive: false,
    noShowAction: undefined,
    noShowLimitReached: false
  } as const;

  it('confirms a new client at once when nothing asks otherwise', () => {
    expect(approvalReason(base)).toBeNull();
  });

  it('waits for a new client when the professional asked to confirm new clients', () => {
    expect(approvalReason({ ...base, confirmNewClients: true })).toBe('newClient');
    expect(approvalReason({ ...base, confirmNewClients: true, isNewClient: false })).toBeNull();
  });

  it('waits for a new client when the free registrations are used and there is no plan', () => {
    expect(approvalReason({ ...base, registrationCount: 10 })).toBe('freeRegistrationsUsed');
    expect(approvalReason({ ...base, registrationCount: 10, planActive: true })).toBeNull();
    // A returning client (a phone she already has) keeps booking freely.
    expect(approvalReason({ ...base, registrationCount: 10, isNewClient: false })).toBeNull();
  });

  it('waits when the no-show limit is reached with the approve action, new or not', () => {
    const noShow = { noShowLimitReached: true, noShowAction: 'approveNewBookings' } as const;
    expect(approvalReason({ ...base, ...noShow, isNewClient: false })).toBe('noShowLimit');
    expect(approvalReason({ ...base, noShowLimitReached: true, noShowAction: 'tell' })).toBeNull();
  });
});

describe('who cannot book online right now', () => {
  const open = {
    acceptingBookings: true,
    pausedUntil: undefined,
    now: 1_000,
    noShowAction: undefined,
    noShowLimitReached: false,
    onlineBookingStopped: false
  } as const;

  it('is open by default', () => {
    expect(isPausedFor(open)).toBe(false);
  });

  it('is paused by the page switch, until the return date, for a stopped client and at the pause limit', () => {
    expect(isPausedFor({ ...open, acceptingBookings: false })).toBe(true);
    expect(isPausedFor({ ...open, pausedUntil: 2_000 })).toBe(true);
    expect(isPausedFor({ ...open, pausedUntil: 1_000 })).toBe(false);
    expect(isPausedFor({ ...open, onlineBookingStopped: true })).toBe(true);
    expect(isPausedFor({ ...open, noShowLimitReached: true, noShowAction: 'pauseOnline' })).toBe(true);
    expect(isPausedFor({ ...open, noShowLimitReached: true, noShowAction: 'tell' })).toBe(false);
  });
});

describe('durations and retention dates', () => {
  it('adds add-ons and guests back to back (D19)', () => {
    expect(totalMinutes(60, [], 0)).toBe(60);
    expect(totalMinutes(60, [15, 10], 0)).toBe(85);
    expect(totalMinutes(60, [15], 2)).toBe(195);
  });

  it('purges seven days after the visit and expires envelopes after thirty days (D30)', () => {
    const ends = Date.UTC(2026, 9, 8, 15);
    expect(purgeAtFor(ends)).toBe(ends + 7 * DAY);
    expect(envelopeExpiresAt(ends)).toBe(ends + 30 * DAY);
  });

  it('keeps a sealed intake valid for twelve months', () => {
    const now = Date.UTC(2026, 9, 8);
    expect(intakeIsCurrent(Date.UTC(2025, 10, 1), now)).toBe(true);
    expect(intakeIsCurrent(Date.UTC(2025, 8, 1), now)).toBe(false);
    expect(intakeIsCurrent(undefined, now)).toBe(false);
  });

  it('names the phase of a visit', () => {
    expect(bookingPhase(100, 200, 50)).toBe('upcoming');
    expect(bookingPhase(100, 200, 100)).toBe('inProgress');
    expect(bookingPhase(100, 200, 200)).toBe('past');
  });
});
