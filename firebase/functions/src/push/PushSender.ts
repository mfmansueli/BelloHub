// Push behind an interface (docs/11 section 7). A message is a KIND and an ID, nothing else: the app resolves the lock
// screen text from a localization key, so a name or a detail can never reach a notification.

export type PushKind = 'booking' | 'bookingLate' | 'bookingConfirmed' | 'rescheduleRequest' | 'waitlist' | 'mailbox';

/**
 * What the client did to a booking, so the alert says it (push-messages notes): a new confirmed booking, a request
 * waiting for her approval (also an unverified WhatsApp request, D58), a client's move, a client's cancellation.
 * It is a word from this closed list, never a detail: no name, service or time.
 */
export type BookingPushEvent = 'new' | 'request' | 'moved' | 'cancelled';

export const BOOKING_PUSH_EVENTS: readonly BookingPushEvent[] = ['new', 'request', 'moved', 'cancelled'];

export interface PushMessage {
  kind: PushKind;
  /** A booking, request, waitlist or item id; empty when the kind needs none. */
  id: string;
  /** Only for `booking`: what happened. Missing means `new` (the meaning the key had before events existed). */
  event?: BookingPushEvent;
}

export interface PushTarget {
  /** The id of the `devices/{uid}/tokens/{id}` document. */
  id: string;
  fcmToken: string;
}

export interface PushResult {
  /** Target ids whose token FCM says is gone; the caller deletes them. */
  invalidTargetIds: string[];
}

export interface PushSender {
  send(targets: PushTarget[], message: PushMessage): Promise<PushResult>;
}

/** An alert: a non-silent kind, with the booking kind split by its event. */
export type PushAlert = `booking.${BookingPushEvent}` | Exclude<PushKind, 'mailbox' | 'booking'>;

/**
 * The `loc-key` of each alert (API.md section 7). `mailbox` has none: it is a silent push. The app must carry a string
 * for every value here in all fourteen localizations, or iOS shows the raw key on the lock screen: the list is
 * published as `contracts/push-keys.json` (`npm run gen:push-keys`) and the iOS tests check the catalog against it.
 */
export const PUSH_ALERT_KEYS: Record<PushAlert, string> = {
  'booking.new': 'push.booking.new',
  'booking.request': 'push.booking.request',
  'booking.moved': 'push.booking.moved',
  'booking.cancelled': 'push.booking.cancelled',
  bookingLate: 'push.booking.late',
  bookingConfirmed: 'push.booking.clientConfirmed',
  rescheduleRequest: 'push.reschedule.request',
  waitlist: 'push.waitlist.new'
};

/** The alert a message raises; nil for the silent `mailbox`. */
export function pushAlertOf(message: PushMessage): PushAlert | undefined {
  if (isSilent(message.kind)) return undefined;
  if (message.kind === 'booking') return `booking.${message.event ?? 'new'}`;
  return message.kind as PushAlert;
}

/** The sorted, distinct keys of `PUSH_ALERT_KEYS`: the content of `contracts/push-keys.json`. */
export function publishedPushKeys(): string[] {
  return [...new Set(Object.values(PUSH_ALERT_KEYS))].sort();
}

export function isSilent(kind: PushKind): boolean {
  return kind === 'mailbox';
}
