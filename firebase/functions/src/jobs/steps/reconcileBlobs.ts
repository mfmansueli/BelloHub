import type { Deps } from '../../app/Deps.js';
import { refs } from '../../lib/store.js';

const MAX_PAGES_PER_RUN = 5;

/**
 * A Storage object whose item document is gone (Firestore's own TTL removed the document and cannot touch Storage) is
 * deleted. Bounded per run; the next run continues, because everything that remains is still unmatched.
 * Paths look like `inbox/{uid}/{itemId}.json`.
 */
export async function reconcileBlobs(deps: Deps): Promise<number> {
  let removed = 0;
  let page: string | undefined;
  for (let pages = 0; pages < MAX_PAGES_PER_RUN; pages += 1) {
    const listed = await deps.blobs.list('inbox/', page);
    for (const path of listed.paths) {
      const match = /^inbox\/([^/]+)\/([^/]+)\.json$/.exec(path);
      const [, uid, itemId] = match ?? [];
      const known = uid && itemId ? (await refs(deps.db).inboxItem(uid, itemId).get()).exists : false;
      if (!known) {
        await deps.blobs.delete(path);
        removed += 1;
      }
    }
    page = listed.next;
    if (!page) break;
  }
  return removed;
}
