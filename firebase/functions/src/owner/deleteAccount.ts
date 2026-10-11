import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import { cascadeDeleteAccount } from '../lib/deletion.js';
import { consumeRate } from '../lib/rateLimit.js';

/**
 * Deletes the whole server side of her account (D30): everything under her uid, her public page and her Auth user.
 * With an Apple authorization code the Sign in with Apple grant is revoked too (D44); Apple refusing or being down
 * is reported, never a reason to keep her data.
 */
export const deleteAccount = defineUseCase({
  name: 'deleteAccount',
  access: 'owner',
  ...contract.deleteAccount,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'deleteAccount', uid, RATE.deleteOwnerDay);
    const appleRevocation = input.appleAuthorizationCode ? await deps.appleRevoker.revoke(input.appleAuthorizationCode) : 'skipped';
    deps.log.info('account.appleRevocation', { ownerUid: uid, status: appleRevocation });
    await cascadeDeleteAccount(deps, uid);
    return { ok: true as const, appleRevocation };
  }
});
