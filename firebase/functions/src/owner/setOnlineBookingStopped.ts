import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import { writeContact } from '../lib/contacts.js';
import type { ContactDoc } from '../lib/docs.js';
import { phoneHashOf } from '../lib/emailProof.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, refs, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/** The "Stop online booking" switch of a client record (ClientEdit): that phone sees the booking page as paused. */
export const setOnlineBookingStopped = defineUseCase({
  name: 'setOnlineBookingStopped',
  access: 'owner',
  ...contract.setOnlineBookingStopped,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    const phoneHash = phoneHashOf(deps.pepper, input.phone);
    const r = refs(deps.db);
    await runTransaction(deps.db, async (tx) => {
      const contact = dataOf<ContactDoc>(await txReader(tx).doc(r.contact(uid, phoneHash)));
      writeContact(tx, r, uid, phoneHash, contact, { onlineBookingStopped: input.stopped }, deps.now());
    });
    return { ok: true as const };
  }
});
