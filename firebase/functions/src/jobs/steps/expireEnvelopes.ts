import type { Deps } from '../../app/Deps.js';
import type { InboxItemDoc } from '../../lib/docs.js';
import { C } from '../../lib/docs.js';
import { ts } from '../../lib/store.js';
import { sweep } from './sweep.js';

/**
 * D30: a sealed envelope is deleted when the app acknowledges it and, as a hard limit, 30 days after it arrived. The
 * Firestore TTL policy does the same on its own schedule; this job is the guarantee, and it removes the Storage object
 * that the TTL cannot reach.
 */
export async function expireEnvelopes(deps: Deps, now: number): Promise<number> {
  return sweep(deps, deps.db.collectionGroup(C.items).where('expiresAt', '<=', ts(now)), async (snapshot) => {
    const item = snapshot.data() as InboxItemDoc | undefined;
    if (item?.storagePath) await deps.blobs.delete(item.storagePath);
  });
}
