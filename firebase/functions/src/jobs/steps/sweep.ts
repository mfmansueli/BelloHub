import type { DocumentReference, DocumentSnapshot, Query } from 'firebase-admin/firestore';

import type { Deps } from '../../app/Deps.js';
import { CLEANUP_BATCH } from '../../config/limits.js';
import { deleteRefs } from '../../lib/deletion.js';

/**
 * Deletes everything a query returns, a batch at a time, until nothing is left. `beforeDelete` lets a step remove
 * related data first (a Storage object). Returns how many documents went.
 */
export async function sweep(
  deps: Deps,
  query: Query,
  beforeDelete?: (snapshot: DocumentSnapshot) => Promise<void>
): Promise<number> {
  let total = 0;
  for (;;) {
    const page = await query.limit(CLEANUP_BATCH).get();
    if (page.empty) return total;
    const refs: DocumentReference[] = [];
    for (const snapshot of page.docs) {
      if (beforeDelete) await beforeDelete(snapshot);
      refs.push(snapshot.ref);
    }
    total += await deleteRefs(deps, refs);
    if (page.size < CLEANUP_BATCH) return total;
  }
}
