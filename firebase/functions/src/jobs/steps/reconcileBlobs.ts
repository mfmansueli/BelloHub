import type { Deps } from '../../app/Deps.js';
import type { InboxItemDoc } from '../../lib/docs.js';
import { refs } from '../../lib/store.js';

const MAX_PAGES_PER_RUN = 5;

/**
 * A Storage object that no item document points at (Firestore's own TTL removed the document and cannot touch Storage,
 * or a lost race left an object the winner never used) is deleted. Bounded per run; the next run continues, because
 * everything that remains is still unmatched. Paths look like `inbox/{uid}/{itemId}.{ctHash16}.json`.
 */
export async function reconcileBlobs(deps: Deps): Promise<number> {
  let removed = 0;
  let page: string | undefined;
  for (let pages = 0; pages < MAX_PAGES_PER_RUN; pages += 1) {
    const listed = await deps.blobs.list('inbox/', page);
    for (const path of listed.paths) {
      const match = /^inbox\/([^/]+)\/([^/.]+)(?:\.[^/]*)?\.json$/.exec(path);
      const [, uid, itemId] = match ?? [];
      const item = uid && itemId ? (await refs(deps.db).inboxItem(uid, itemId).get()).data() as InboxItemDoc | undefined : undefined;
      const known = item?.storagePath === path;
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
