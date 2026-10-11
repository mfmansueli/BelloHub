import type { Deps } from '../app/Deps.js';
import type { BookingDoc } from '../lib/docs.js';
import { waitlistMatchesFor } from '../lib/waitlistMatch.js';
import { notifyOwner } from '../push/notifyOwner.js';
import type { PushMessage } from '../push/PushSender.js';

type ClientAction = NonNullable<BookingDoc['lastClientAction']>['kind'];

/**
 * What each client action pushes. A move and a cancellation are `booking` pushes (the tap opens the booking) whose
 * event makes the alert say what happened; before events they all read "new booking".
 */
const MESSAGE_OF_ACTION: Record<ClientAction, Pick<PushMessage, 'kind' | 'event'>> = {
  rescheduled: { kind: 'booking', event: 'moved' },
  confirmed: { kind: 'bookingConfirmed' },
  late: { kind: 'bookingLate' },
  cancelled: { kind: 'booking', event: 'cancelled' }
};

/**
 * Pushes a generic message to the professional's devices when the CLIENT did something (docs/11 section 3): a new
 * booking or request, a change, a cancellation, a confirmation, a late arrival. The payload is a kind, the booking id
 * and, for a booking, the event (new, request, moved, cancelled), never a name. A new booking that waits for her
 * approval (`pendingApproval`, also the unverified WhatsApp requests of D58) is a `request`, anything else `new`. What she does herself (approve, cancel, move) is not echoed back to her. A cancellation also checks the
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
    const event = after.status === 'pendingApproval' ? 'request' : 'new';
    await notifyOwner(deps, after.ownerUid, { kind: 'booking', id: bookingId, event });
    return;
  }
  const action = after.lastClientAction;
  const previous = before.lastClientAction;
  const unchanged = previous?.kind === action?.kind && previous?.at.toMillis() === action?.at.toMillis();
  if (!action || unchanged) return;

  await notifyOwner(deps, after.ownerUid, { ...MESSAGE_OF_ACTION[action.kind], id: bookingId });
  if (action.kind === 'cancelled') {
    const matches = await waitlistMatchesFor(deps, after);
    const first = matches[0];
    if (first) await notifyOwner(deps, after.ownerUid, { kind: 'waitlist', id: first.id });
  }
}
