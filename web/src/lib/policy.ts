// What a client may do with a booking, from the cancellation policy stored on it (docs/10 section 4, D11, D12).
// This decides which buttons the management page shows. The server stays authoritative: it evaluates the same
// snapshot again and refuses what the policy does not allow, so a wrong clock here cannot grant anything.
// Both implementations read the table in test/fixtures/policy-cases.json (docs/11 section 4).

export interface PolicyValues {
  /** Free changes up to this many hours before the visit (2, 12, 24, 48 or 72). */
  readonly freeWindowHours: number;
  readonly clientCanReschedule: boolean;
  /** Null or missing means as often as she needs. */
  readonly maxReschedules?: number | null;
  /** After the free window: `allow` cancels here with an honest warning, `message` asks her to write. */
  readonly afterWindowCancel: 'allow' | 'message';
  /** After the free window: `request` sends a request she answers, `message` asks her to write. */
  readonly afterWindowReschedule: 'request' | 'message';
  readonly askConfirmation: boolean;
  /** Minutes she holds the time when a client says she is running late. */
  readonly graceMinutes: number;
  /** A late cancellation counts as a missed appointment (no-show protection is on and `lateCancelCounts`). */
  readonly lateCancelCounts?: boolean;
  /** The limit of missed appointments before she steps in, when no-show protection is on. */
  readonly noShowLimit?: number | null;
}

export type CancelMode = 'free' | 'allowLate' | 'message';
export type RescheduleMode = 'direct' | 'request' | 'message';

const HOUR = 3_600_000;

/** The last instant at which changes are free. */
export function freeUntil(startsAt: number, policy: PolicyValues): number {
  return startsAt - policy.freeWindowHours * HOUR;
}

export function isInsideFreeWindow(startsAt: number, policy: PolicyValues, now: number): boolean {
  return now <= freeUntil(startsAt, policy);
}

export function cancelMode(startsAt: number, policy: PolicyValues, now: number): CancelMode {
  if (isInsideFreeWindow(startsAt, policy, now)) return 'free';
  return policy.afterWindowCancel === 'allow' ? 'allowLate' : 'message';
}

export function reschedulesLeft(policy: PolicyValues, rescheduleCount: number): number | null {
  if (policy.maxReschedules === undefined || policy.maxReschedules === null) return null;
  return Math.max(0, policy.maxReschedules - rescheduleCount);
}

export function rescheduleMode(
  startsAt: number,
  policy: PolicyValues,
  now: number,
  rescheduleCount: number,
): RescheduleMode {
  if (!policy.clientCanReschedule) return 'message';
  if (reschedulesLeft(policy, rescheduleCount) === 0) return 'message';
  if (isInsideFreeWindow(startsAt, policy, now)) return 'direct';
  return policy.afterWindowReschedule;
}

/** Whether a late cancellation would count against her (shown as a warning before she confirms). */
export function lateCancelCountsAgainst(mode: CancelMode, policy: PolicyValues): boolean {
  return mode === 'allowLate' && policy.lateCancelCounts === true;
}
