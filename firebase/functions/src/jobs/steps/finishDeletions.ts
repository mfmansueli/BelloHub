import type { Deps } from '../../app/Deps.js';
import { C } from '../../lib/docs.js';
import { cascadeDeleteAccount } from '../../lib/deletion.js';
import { ts } from '../../lib/store.js';

const MAX_PER_RUN = 20;

/**
 * The promise to users is that deleting an account completes within 30 days (D30). `deleteAccount` does it at once; if it
 * was interrupted, the account document still carries `deletion.requestedAt`, and this step finishes the job.
 */
export async function finishDeletions(deps: Deps): Promise<number> {
  const pending = await deps.db
    .collection(C.accounts)
    .where('deletion.requestedAt', '>', ts(0))
    .limit(MAX_PER_RUN)
    .get();
  for (const account of pending.docs) await cascadeDeleteAccount(deps, account.id);
  return pending.size;
}
