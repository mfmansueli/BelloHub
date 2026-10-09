import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import type { InboxItemDoc } from '../lib/docs.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, refs } from '../lib/store.js';

/**
 * The app imported the item into her vault (idempotent by item id), so the server deletes it, with its Storage object,
 * at once (D30, docs/06 section 3.5 step 4). Unknown ids succeed: a retry after a crash must not fail.
 */
export const acknowledgeMailboxItem = defineUseCase({
  name: 'acknowledgeMailboxItem',
  access: 'owner',
  ...contract.acknowledgeMailboxItem,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'mailbox', uid, RATE.mailboxOwner);
    const ref = refs(deps.db).inboxItem(uid, input.itemId);
    const item = dataOf<InboxItemDoc>(await ref.get());
    if (item?.storagePath) await deps.blobs.delete(item.storagePath);
    if (item) await ref.delete();
    deps.log.info('mailbox.acknowledged', { ownerUid: uid, itemId: input.itemId });
    return { ok: true as const };
  }
});
