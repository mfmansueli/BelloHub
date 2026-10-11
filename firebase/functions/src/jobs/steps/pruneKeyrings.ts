import type { Deps } from '../../app/Deps.js';
import type { AccountDoc } from '../../lib/docs.js';
import { C } from '../../lib/docs.js';
import { pruneKeyring } from '../../lib/keyring.js';
import { keyringUpdate } from '../../lib/keyringUpdate.js';
import { dataOf, ts } from '../../lib/store.js';
import { runTransaction } from '../../lib/tx.js';

const MAX_PER_RUN = 50;

/**
 * Drops retired inbox keys that no envelope can reference any more (D51): the grace window closed and every envelope
 * it could have received has expired (30 days). Only accounts whose `inboxKeyringPruneAt` is due are read, so the step
 * costs nothing while nobody rotates. Returns how many rings were rewritten.
 */
export async function pruneKeyrings(deps: Deps, now: number): Promise<number> {
  const due = await deps.db.collection(C.accounts).where('inboxKeyringPruneAt', '<=', ts(now)).limit(MAX_PER_RUN).get();
  let pruned = 0;
  for (const found of due.docs) {
    await runTransaction(deps.db, async (tx) => {
      const account = dataOf<AccountDoc>(await tx.get(found.ref));
      if (!account) return;
      const kept = pruneKeyring(account.inboxKeyring, now);
      tx.update(found.ref, keyringUpdate(kept, now));
      if (kept.length !== account.inboxKeyring.length) pruned += 1;
    });
  }
  return pruned;
}
