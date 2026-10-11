import type { Message } from 'firebase-admin/messaging';

import type { PushMessage } from './PushSender.js';
import { PUSH_ALERT_KEYS, isSilent, pushAlertOf } from './PushSender.js';

/**
 * The FCM message for one device. Pure, so a test can assert that nothing but a kind, an id and a localization key
 * is ever sent. The alert carries `loc-key` (the SDK's `locKey`) and NO `loc-args`: no name can be interpolated on
 * the server, and the app resolves the text in the user's language. A booking push also carries `data.event` (a word
 * from a closed list, ignored by apps that predate it); the tap routing still reads only `kind` and `id`.
 */
export function buildFcmMessage(token: string, message: PushMessage): Message {
  const data: Record<string, string> = { kind: message.kind, id: message.id };
  if (message.kind === 'booking') data.event = message.event ?? 'new';
  if (isSilent(message.kind)) {
    return {
      token,
      data,
      apns: {
        headers: { 'apns-push-type': 'background', 'apns-priority': '5' },
        payload: { aps: { contentAvailable: true } }
      }
    };
  }
  const key = PUSH_ALERT_KEYS[pushAlertOf(message) ?? 'booking.new'];
  const urgent = message.kind === 'bookingLate';
  return {
    token,
    data,
    apns: {
      headers: { 'apns-push-type': 'alert', 'apns-priority': urgent ? '10' : '5' },
      payload: {
        aps: {
          alert: { locKey: key },
          sound: 'default',
          // A client running late is urgent and ignores quiet hours (docs/05 NotificationPrefs).
          ...(urgent ? { customData: { 'interruption-level': 'time-sensitive' } } : {})
        }
      }
    }
  };
}
