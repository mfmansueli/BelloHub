import type { BookingDoc } from './docs.js';
import { ACTIVE_BOOKING_STATUSES } from './docs.js';
import type { BookingPhase, CancelDecision, RescheduleDecision } from './rules.js';
import { bookingPhase, decideCancellation } from './rules.js';
import { ms } from './store.js';

export interface ClientActions {
  phase: BookingPhase;
  cancel: CancelDecision;
  reschedule: RescheduleDecision;
  isInsideFreeWindow: boolean;
  hoursUntilStart: number;
  cancellationWouldBeLate: boolean;
  canConfirmPresence: boolean;
  canReportLate: boolean;
}

const THREE_HOURS_MS = 3 * 3_600_000;

/**
 * What the client may do with this booking at `now`, from the policy copied onto it when it was made (docs/11 section 4).
 * A request that still waits for the professional can be withdrawn freely but not moved: she has not agreed to the
 * first time yet, so the client is sent to message her.
 */
export function clientActions(booking: BookingDoc, now: number): ClientActions {
  const startsAt = ms(booking.startsAt);
  const phase = bookingPhase(startsAt, ms(booking.endsAt), now);
  const decision = decideCancellation(booking.policy, startsAt, now, booking.rescheduleCount);
  const active = ACTIVE_BOOKING_STATUSES.includes(booking.status);

  if (!active || phase === 'past') {
    return {
      phase,
      cancel: 'unavailable',
      reschedule: 'unavailable',
      isInsideFreeWindow: false,
      hoursUntilStart: decision.hoursUntilStart,
      cancellationWouldBeLate: false,
      canConfirmPresence: false,
      canReportLate: false
    };
  }

  const pending = booking.status === 'pendingApproval';
  const cancel: CancelDecision = pending ? (decision.cancel === 'unavailable' ? 'unavailable' : 'free') : decision.cancel;
  const reschedule: RescheduleDecision = pending && decision.reschedule !== 'unavailable' ? 'message' : decision.reschedule;
  const confirmed = booking.status === 'confirmed';
  return {
    phase,
    cancel,
    reschedule,
    isInsideFreeWindow: decision.isInsideFreeWindow,
    hoursUntilStart: decision.hoursUntilStart,
    cancellationWouldBeLate: cancel === 'allowedWithWarning',
    canConfirmPresence: confirmed && booking.policy.askConfirmation && !booking.clientConfirmedAt && phase === 'upcoming',
    canReportLate: confirmed && (phase === 'inProgress' || startsAt - now <= THREE_HOURS_MS)
  };
}
