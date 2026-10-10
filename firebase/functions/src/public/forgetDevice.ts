import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/public.js';
import { consumeRate } from '../lib/rateLimit.js';
import { revokeTrustedDevice } from '../lib/trustedDevices.js';

/**
 * "Forget this device" (verify-fallback item 2): the browser hands back its trusted-device token and the server deletes
 * it, so the next booking asks for a code again. The answer is the same whether or not the token existed.
 */
export const forgetDevice = defineUseCase({
  name: 'forgetDevice',
  access: 'public',
  ...contract.forgetDevice,
  async handle(deps, input, ctx) {
    await consumeRate(deps, 'forgetDeviceIp', ctx.ipHash, RATE.forgetDeviceIp);
    await revokeTrustedDevice(deps, input.token);
    return { ok: true as const };
  }
});
