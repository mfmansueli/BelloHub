import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import { ensureAccountExists } from '../lib/account.js';
import { writeAudit } from '../lib/audit.js';
import type { AccountDoc, SlugDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * Claims the booking address in a transaction (`slugs/{slug}` is the unique claim). Claiming a new one releases the old
 * one and removes the old public page; the app publishes the profile again under the new slug.
 */
export const claimSlug = defineUseCase({
  name: 'claimSlug',
  access: 'owner',
  ...contract.claimSlug,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'slugCheck', uid, RATE.slugCheckOwner);
    await ensureAccountExists(deps, uid, ctx);
    const r = refs(deps.db);
    const now = deps.now();

    await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const account = dataOf<AccountDoc>(await reader.doc(r.account(uid)));
      const claim = dataOf<SlugDoc>(await reader.doc(r.slug(input.slug)));
      if (claim && claim.ownerUid !== uid) throw new AppError('SLUG_TAKEN');
      if (claim && account?.slug === input.slug) return;

      if (!claim) tx.create(r.slug(input.slug), { ownerUid: uid, claimedAt: ts(now) } satisfies SlugDoc);
      if (account?.slug && account.slug !== input.slug) {
        tx.delete(r.slug(account.slug));
        tx.delete(r.profile(account.slug));
        writeAudit(tx, deps, { kind: 'slugChanged', uid });
      }
      tx.update(r.account(uid), { slug: input.slug, updatedAt: ts(now) });
    });
    return { slug: input.slug };
  }
});
