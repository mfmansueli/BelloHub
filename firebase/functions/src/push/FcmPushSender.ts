import { getMessaging } from 'firebase-admin/messaging';

import { buildFcmMessage } from './fcmMessage.js';
import type { PushMessage, PushResult, PushSender, PushTarget } from './PushSender.js';

const INVALID_TOKEN_CODES = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);

/** FCM through the Admin SDK. Needs the APNs auth key uploaded by a human in the Firebase console (H4). */
export class FcmPushSender implements PushSender {
  async send(targets: PushTarget[], message: PushMessage): Promise<PushResult> {
    if (targets.length === 0) return { invalidTargetIds: [] };
    const response = await getMessaging().sendEach(targets.map((target) => buildFcmMessage(target.fcmToken, message)));
    const invalidTargetIds: string[] = [];
    response.responses.forEach((result, index) => {
      const target = targets[index];
      if (!result.success && target && result.error && INVALID_TOKEN_CODES.has(result.error.code)) {
        invalidTargetIds.push(target.id);
      }
    });
    return { invalidTargetIds };
  }
}
