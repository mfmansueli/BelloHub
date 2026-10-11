import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import { consumeRate } from '../lib/rateLimit.js';
import { refs } from '../lib/store.js';
import { deviceId } from './registerDevice.js';

/** Sign-out on a device: its token stops receiving pushes. */
export const unregisterDevice = defineUseCase({
  name: 'unregisterDevice',
  access: 'owner',
  ...contract.unregisterDevice,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    await refs(deps.db).device(uid, deviceId(input.fcmToken)).delete();
    return { ok: true as const };
  }
});
