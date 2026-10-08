import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import type { Envelope } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import type { InboxItemDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, ms, refs } from '../lib/store.js';

/**
 * Hands the app one sealed envelope (docs/06 section 3.5, step 3). Small envelopes are also readable straight from
 * Firestore; this function is the way to get those kept in Cloud Storage. The server returns ciphertext it cannot open.
 */
export const getMailboxItem = defineUseCase({
  name: 'getMailboxItem',
  access: 'owner',
  ...contract.getMailboxItem,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'mailbox', uid, RATE.mailboxOwner);
    const item = dataOf<InboxItemDoc>(await refs(deps.db).inboxItem(uid, input.itemId).get());
    if (!item) throw new AppError('NOT_FOUND');

    let envelope: Envelope | undefined = item.envelope as Envelope | undefined;
    if (!envelope && item.storagePath) {
      const bytes = await deps.blobs.get(item.storagePath);
      if (!bytes) throw new AppError('NOT_FOUND');
      envelope = JSON.parse(bytes.toString('utf8')) as Envelope;
    }
    if (!envelope) throw new AppError('NOT_FOUND');
    return {
      itemId: input.itemId,
      kind: item.kind,
      bookingId: item.bookingId,
      createdAt: iso(ms(item.createdAt)),
      envelope
    };
  }
});
