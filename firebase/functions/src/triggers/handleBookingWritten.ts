import type { Deps } from '../app/Deps.js';
import type { BookingDoc } from '../lib/docs.js';
import { waitlistMatchesFor } from '../lib/waitlistMatch.js';
import { notifyOwner } from '../push/notifyOwner.js';
import type { PushKind } from '../push/PushSender.js';

const KIND_OF_ACTION: Record<NonNullable<BookingDoc['lastClientAction']>['kind'], PushKind> = {
  rescheduled: 'booking',
  confirmed: 'bookingConfirmed',
  late: 'bookingLate',
  cancelled: 'booking'
};

/**
 * Pushes a generic message to the professional's devices when the CLIENT did something (docs/11 section 3): a new
 * booking or request, a change, a cancellation, a confirmation, a late arrival. The payload is a kind and the booking id,
 * never a name. What she does herself (approve, cancel, move) is not echoed back to her. A cancellation also checks the
 * waitlist and pushes `waitlist` when somebody could take the freed time.
 */
export async function handleBookingWritten(
  deps: Deps,
  bookingId: string,
  before: BookingDoc | undefined,
  after: BookingDoc | undefined
): Promise<void> {
  if (!after) return;
  if (!before) {
    await notifyOwner(deps, after.ownerUid, { kind: 'booking', id: bookingId });
    return;
  }
  const action = after.lastClientAction;
  const previous = before.lastClientAction;
  const unchanged = previous?.kind === action?.kind && previous?.at.toMillis() === action?.at.toMillis();
  if (!action || unchanged) return;

  await notifyOwner(deps, after.ownerUid, { kind: KIND_OF_ACTION[action.kind], id: bookingId });
  if (action.kind === 'cancelled') {
    const matches = await waitlistMatchesFor(deps, after);
    const first = matches[0];
    if (first) await notifyOwner(deps, after.ownerUid, { kind: 'waitlist', id: first.id });
  }
}
