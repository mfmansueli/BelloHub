import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import { ensureAccountExists } from '../lib/account.js';
import { writeAudit } from '../lib/audit.js';
import { inboxKeyId } from '../lib/crypto.js';
import type { AccountDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { applyInboxKey, keyringView } from '../lib/keyring.js';
import { keyringUpdate } from '../lib/keyringUpdate.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, ms, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * Key rotation (docs/06 section 3.2, D51): the new key becomes current in the ring and in the public page; the earlier
 * key is retired and accepts new envelopes for 24 more hours (at once closed when `compromised`), and stays listed
 * until nothing in the mailbox can need it. Only the owner can write it; the event is logged without values.
 */
export const updateInboxKey = defineUseCase({
  name: 'updateInboxKey',
  access: 'owner',
  ...contract.updateInboxKey,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'publish', uid, RATE.publishOwner);
    if (inboxKeyId(input.inboxKey.pub) !== input.inboxKey.keyId) {
      throw new AppError('INVALID_ARGUMENT', { fields: ['inboxKey'] });
    }
    await ensureAccountExists(deps, uid, ctx);
    const r = refs(deps.db);
    const now = deps.now();

    const keyring = await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const account = dataOf<AccountDoc>(await reader.doc(r.account(uid)));
      if (!account) throw new AppError('NOT_FOUND');
      const profileSnap = account.slug ? await reader.doc(r.profile(account.slug)) : undefined;
      const applied = applyInboxKey(account.inboxKeyring, input.inboxKey, now, { compromised: input.compromised });
      if ('failure' in applied) throw new AppError('INVALID_ARGUMENT', { fields: ['inboxKey'] });
      if (applied.changed) {
        tx.update(r.account(uid), keyringUpdate(applied.keyring, now));
        writeAudit(tx, deps, { kind: 'inboxKeyChanged', uid, keyId: input.inboxKey.keyId });
      }
      if (profileSnap?.exists && account.slug) {
        tx.update(r.profile(account.slug), { inboxKey: input.inboxKey, updatedAt: ts(now) });
      }
      return applied.keyring;
    });
    return {
      keyring: keyringView(keyring).map((entry) => ({
        keyId: entry.keyId,
        createdAt: iso(ms(entry.createdAt)),
        ...(entry.retiredAt ? { retiredAt: iso(ms(entry.retiredAt)) } : {}),
        ...(entry.acceptsUntil ? { acceptsUntil: iso(ms(entry.acceptsUntil)) } : {}),
        ...(entry.compromisedAt ? { compromisedAt: iso(ms(entry.compromisedAt)) } : {})
      }))
    };
  }
});
