// Push behind an interface (docs/11 section 7). A message is a KIND and an ID, nothing else: the app resolves the lock
// screen text from a localization key, so a name or a detail can never reach a notification.

export type PushKind = 'booking' | 'bookingLate' | 'bookingConfirmed' | 'rescheduleRequest' | 'waitlist' | 'mailbox';

export interface PushMessage {
  kind: PushKind;
  /** A booking, request, waitlist or item id; empty when the kind needs none. */
  id: string;
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

/** The `loc-key` of each alert (API.md section 7). `mailbox` has none: it is a silent push. */
export const PUSH_ALERT_KEYS: Record<Exclude<PushKind, 'mailbox'>, string> = {
  booking: 'push.booking.new',
  bookingLate: 'push.booking.late',
  bookingConfirmed: 'push.booking.clientConfirmed',
  rescheduleRequest: 'push.reschedule.request',
  waitlist: 'push.waitlist.new'
};

export function isSilent(kind: PushKind): boolean {
  return kind === 'mailbox';
}
