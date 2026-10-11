import type { Firestore } from 'firebase-admin/firestore';
import { Timestamp } from 'firebase-admin/firestore';

import { C } from '../lib/docs.js';
import type { PushMessage, PushResult, PushSender, PushTarget } from './PushSender.js';

/**
 * Used only inside the emulator, where FCM is unreachable: it records the kind and id of what would have been sent so
 * an end-to-end test (or the web agent's Playwright run) can wait on it. Never constructed outside the emulator.
 */
export class EmulatorPushSender implements PushSender {
  constructor(private readonly db: Firestore) {}

  async send(targets: PushTarget[], message: PushMessage): Promise<PushResult> {
    if (targets.length === 0) return { invalidTargetIds: [] };
    await this.db.collection(C.emulatorOutbox).add({
      type: 'push',
      kind: message.kind,
      id: message.id,
      ...(message.event ? { event: message.event } : {}),
      devices: targets.length,
      at: Timestamp.now()
    });
    return { invalidTargetIds: [] };
  }
}
