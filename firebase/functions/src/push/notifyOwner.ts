import type { Deps } from '../app/Deps.js';
import type { DeviceDoc } from '../lib/docs.js';
import { refs } from '../lib/store.js';
import type { PushMessage } from './PushSender.js';

/**
 * Pushes a kind and an id to every device of the professional (docs/11 section 7). Best effort: a failed push never
 * fails the action that caused it. Tokens FCM reports as gone are deleted. Returns how many devices were targeted.
 */
export async function notifyOwner(deps: Deps, ownerUid: string, message: PushMessage): Promise<number> {
  try {
    const snapshot = await refs(deps.db).devices(ownerUid).get();
    const targets = snapshot.docs.map((doc) => ({ id: doc.id, fcmToken: (doc.data() as DeviceDoc).fcmToken }));
    if (targets.length === 0) return 0;
    const result = await deps.push.send(targets, message);
    await Promise.all(result.invalidTargetIds.map((id) => refs(deps.db).device(ownerUid, id).delete()));
    deps.log.info('push.sent', { ownerUid, kind: message.kind, count: targets.length, failed: result.invalidTargetIds.length });
    return targets.length;
  } catch {
    deps.log.warn('push.failed', { ownerUid, kind: message.kind });
    return 0;
  }
}
