// Booking rules as pure functions of their inputs (docs/11-BACKEND-FIREBASE.md section 4). Nothing here reads a
// clock or a database: `now` is always a parameter, so every rule is table-testable.
//
// Mirrors of iOS types, kept equal by test/fixtures/rules.fixture.json (generated from the Swift code):
//   decideCancellation  <- CancellationEvaluator.decide
//   isLateCancellation  <- CancellationEvaluator.isLateCancellation
//   registrationDecision<- RegistrationQuota (D42)

export interface CancellationPolicy {
  /** The options the app offers (docs/05). */
  freeWindowHours: 2 | 12 | 24 | 48 | 72;
  clientCanReschedule: boolean;
  maxReschedules?: number | undefined;
  afterWindowCancel: 'allow' | 'message';
  afterWindowReschedule: 'request' | 'message';
  askConfirmation: boolean;
  graceMinutes: number;
}

export type CancelDecision = 'free' | 'allowedWithWarning' | 'askByMessage' | 'unavailable';
export type RescheduleDecision = 'direct' | 'request' | 'message' | 'unavailable';

export interface CancellationDecision {
  cancel: CancelDecision;
  reschedule: RescheduleDecision;
  isInsideFreeWindow: boolean;
  hoursUntilStart: number;
  cancellationWouldBeLate: boolean;
}

const HOUR_MS = 3_600_000;

/** What a client can do about a visit right now, by the professional's rules (D11, D12). */
export function decideCancellation(
  policy: CancellationPolicy,
  startsAt: number,
  now: number,
  rescheduleCount: number
): CancellationDecision {
  const hours = (startsAt - now) / HOUR_MS;
  if (hours <= 0) {
    return {
      cancel: 'unavailable',
      reschedule: 'unavailable',
      isInsideFreeWindow: false,
      hoursUntilStart: hours,
      cancellationWouldBeLate: false
    };
  }
  // Free up to and including the boundary: exactly 24 h before is still inside a 24 h window.
  const inside = hours >= policy.freeWindowHours;
  const cancel: CancelDecision = inside ? 'free' : policy.afterWindowCancel === 'allow' ? 'allowedWithWarning' : 'askByMessage';
  return {
    cancel,
    reschedule: decideReschedule(policy, inside, rescheduleCount),
    isInsideFreeWindow: inside,
    hoursUntilStart: hours,
    cancellationWouldBeLate: cancel === 'allowedWithWarning'
  };
}

function decideReschedule(policy: CancellationPolicy, inside: boolean, rescheduleCount: number): RescheduleDecision {
  if (!policy.clientCanReschedule) return 'message';
  if (policy.maxReschedules !== undefined && rescheduleCount >= policy.maxReschedules) return 'message';
  if (inside) return 'direct';
  return policy.afterWindowReschedule === 'request' ? 'request' : 'message';
}

/** A cancellation by the client at `cancelledAt` is late when it is inside the free window. */
export function isLateCancellation(policy: CancellationPolicy, startsAt: number, cancelledAt: number): boolean {
  return (startsAt - cancelledAt) / HOUR_MS < policy.freeWindowHours;
}

// MARK: - Free registrations (D42)

export const FREE_REGISTRATION_LIMIT = 10;

export type PlanState = 'none' | 'active' | 'grace' | 'expired' | 'revoked';

export interface StoredPlan {
  state: PlanState;
  expiresAt?: number | undefined;
}

/** A plan unlocks unlimited registrations while it is active, or in the billing grace period, and not yet expired. */
export function isPlanActive(plan: StoredPlan | undefined, now: number): boolean {
  if (!plan) return false;
  if (plan.state !== 'active' && plan.state !== 'grace') return false;
  return plan.expiresAt === undefined || plan.expiresAt > now;
}

export type RegistrationVerdict = 'allowed' | 'needsSubscription';

/** May one more NEW client be registered? The count keeps rising with a plan; only the verdict changes. */
export function registrationDecision(count: number, planActive: boolean): RegistrationVerdict {
  return planActive || Math.max(count, 0) < FREE_REGISTRATION_LIMIT ? 'allowed' : 'needsSubscription';
}

// MARK: - Approval and pause

export type NoShowAction = 'tell' | 'approveNewBookings' | 'pauseOnline';

export interface NoShowPolicy {
  isOn: boolean;
  limit: number;
  action: NoShowAction;
  lateCancelCounts: boolean;
  countingMonths: number;
}

export interface NoShowMark {
  id: string;
  at: number;
  kind: 'noShow' | 'lateCancel';
}

/** What counts against a client under the professional's policy (D13): old marks fade, a reset starts from zero. */
export function countedNoShows(
  policy: NoShowPolicy,
  marks: readonly NoShowMark[],
  resetAt: number | undefined,
  now: number
): number {
  if (!policy.isOn) return 0;
  const periodStart = addMonthsUtc(now, -policy.countingMonths);
  return marks.filter((mark) => {
    if (mark.at < periodStart || mark.at > now) return false;
    // "Start her count from zero": nothing at or before the reset counts, the next mark starts a fresh count.
    if (resetAt !== undefined && mark.at <= resetAt) return false;
    return mark.kind === 'noShow' || policy.lateCancelCounts;
  }).length;
}

function addMonthsUtc(ms: number, months: number): number {
  const date = new Date(ms);
  date.setUTCMonth(date.getUTCMonth() + months);
  return date.getTime();
}

export type PendingReason = 'newClient' | 'freeRegistrationsUsed' | 'noShowLimit';

export interface ApprovalInput {
  confirmNewClients: boolean;
  isNewClient: boolean;
  registrationCount: number;
  planActive: boolean;
  noShowAction: NoShowAction | undefined;
  noShowLimitReached: boolean;
}

/**
 * Why a booking must wait for the professional, or null when it is confirmed at once (D13, D15, D42).
 * Order: the no-show limit about this client first, then the free registrations (the owner must see the paywall
 * reason), then her own "confirm new clients" switch.
 */
export function approvalReason(input: ApprovalInput): PendingReason | null {
  if (input.noShowLimitReached && input.noShowAction === 'approveNewBookings') return 'noShowLimit';
  if (input.isNewClient && registrationDecision(input.registrationCount, input.planActive) === 'needsSubscription') {
    return 'freeRegistrationsUsed';
  }
  if (input.isNewClient && input.confirmNewClients) return 'newClient';
  return null;
}

export interface PauseInput {
  acceptingBookings: boolean;
  pausedUntil: number | undefined;
  now: number;
  noShowAction: NoShowAction | undefined;
  noShowLimitReached: boolean;
  onlineBookingStopped: boolean;
}

/** True when this client cannot book online right now. */
export function isPausedFor(input: PauseInput): boolean {
  if (!input.acceptingBookings) return true;
  if (input.pausedUntil !== undefined && input.pausedUntil > input.now) return true;
  if (input.onlineBookingStopped) return true;
  return input.noShowLimitReached && input.noShowAction === 'pauseOnline';
}

// MARK: - Durations

export const MAX_TOTAL_MINUTES = 12 * 60;

/** Service plus add-ons plus guests, back to back with the same service (D19). */
export function totalMinutes(serviceMinutes: number, addOnMinutes: readonly number[], guests: number): number {
  return serviceMinutes + addOnMinutes.reduce((sum, minutes) => sum + minutes, 0) + guests * serviceMinutes;
}

// MARK: - Retention (D30)

export const PURGE_AFTER_VISIT_DAYS = 7;
export const ENVELOPE_TTL_DAYS = 30;
export const HOLD_MINUTES = 5;
export const PORTAL_IDLE_DAYS = 180;
export const INTAKE_VALID_MONTHS = 12;

const DAY_MS = 86_400_000;

export function purgeAtFor(endsAt: number): number {
  return endsAt + PURGE_AFTER_VISIT_DAYS * DAY_MS;
}

export function envelopeExpiresAt(now: number): number {
  return now + ENVELOPE_TTL_DAYS * DAY_MS;
}

export function intakeIsCurrent(lastIntakeAt: number | undefined, now: number): boolean {
  return lastIntakeAt !== undefined && lastIntakeAt > addMonthsUtc(now, -INTAKE_VALID_MONTHS);
}

export type BookingPhase = 'upcoming' | 'inProgress' | 'past';

export function bookingPhase(startsAt: number, endsAt: number, now: number): BookingPhase {
  if (now < startsAt) return 'upcoming';
  return now < endsAt ? 'inProgress' : 'past';
}
