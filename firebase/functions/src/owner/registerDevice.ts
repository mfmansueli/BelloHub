import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import { sha256Hex } from '../lib/crypto.js';
import type { DeviceDoc } from '../lib/docs.js';
import { consumeRate } from '../lib/rateLimit.js';
import { refs, ts } from '../lib/store.js';

export function deviceId(fcmToken: string): string {
  return sha256Hex(`device:${fcmToken}`).slice(0, 32);
}

/** Registers (or refreshes) the FCM token of one of her devices. The same token twice is one document. */
export const registerDevice = defineUseCase({
  name: 'registerDevice',
  access: 'owner',
  ...contract.registerDevice,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    const doc: DeviceDoc = {
      fcmToken: input.fcmToken,
      platform: input.platform,
      ...(input.locale ? { locale: input.locale } : {}),
      lastSeenAt: ts(deps.now())
    };
    await refs(deps.db).device(uid, deviceId(input.fcmToken)).set(doc);
    return { ok: true as const };
  }
});
