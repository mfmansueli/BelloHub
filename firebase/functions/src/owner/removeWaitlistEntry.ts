import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import type { WaitlistDoc } from '../lib/docs.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, refs } from '../lib/store.js';

/** She takes someone off the waitlist. An id that is not hers (or not there) is a quiet success: nothing to remove. */
export const removeWaitlistEntry = defineUseCase({
  name: 'removeWaitlistEntry',
  access: 'owner',
  ...contract.removeWaitlistEntry,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    const ref = refs(deps.db).waitlistEntry(input.waitlistId);
    const entry = dataOf<WaitlistDoc>(await ref.get());
    if (entry?.ownerUid === uid) await ref.delete();
    return { ok: true as const };
  }
});
