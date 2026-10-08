import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import { cascadeDeleteAccount } from '../lib/deletion.js';
import { consumeRate } from '../lib/rateLimit.js';

/** Deletes the whole server side of her account (D30): everything under her uid, her public page and her Auth user. */
export const deleteAccount = defineUseCase({
  name: 'deleteAccount',
  access: 'owner',
  ...contract.deleteAccount,
  async handle(deps, _input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'deleteAccount', uid, RATE.deleteOwnerDay);
    await cascadeDeleteAccount(deps, uid);
    return { ok: true as const };
  }
});
