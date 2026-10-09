import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import { planFromTransaction, shouldReplacePlan } from '../billing/plan.js';
import { ensureAccountExists } from '../lib/account.js';
import type { AccountDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, msOpt, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * Re-verifies a StoreKit 2 purchase on the server before anything unlocks (CLAUDE.md: purchases are re-verified on the
 * server). The transaction must be for this account (`appAccountToken`) and one of the plan's products (D33).
 */
export const syncPlan = defineUseCase({
  name: 'syncPlan',
  access: 'owner',
  ...contract.syncPlan,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    const account = await ensureAccountExists(deps, uid, ctx);

    const verified = await deps.appStore.verifyTransaction(input.signedTransaction);
    if (!deps.settings.planProductIds.includes(verified.productId)) throw new AppError('VERIFICATION_FAILED');
    if (verified.appAccountToken?.toLowerCase() !== account.appAccountToken) throw new AppError('VERIFICATION_FAILED');

    const now = deps.now();
    const candidate = planFromTransaction(verified, now);
    const plan = await runTransaction(deps.db, async (tx) => {
      const ref = refs(deps.db).account(uid);
      const current = dataOf<AccountDoc>(await txReader(tx).doc(ref));
      if (!current) throw new AppError('NOT_FOUND');
      const stored = { state: current.plan.state, expiresAt: msOpt(current.plan.expiresAt) };
      if (!shouldReplacePlan(stored, candidate)) return stored;
      tx.update(ref, {
        plan: { state: candidate.state, source: 'appStore', ...(candidate.expiresAt !== undefined ? { expiresAt: ts(candidate.expiresAt) } : {}) },
        updatedAt: ts(now)
      });
      return candidate;
    });
    return { plan: { state: plan.state, ...(plan.expiresAt !== undefined ? { expiresAt: iso(plan.expiresAt) } : {}) } };
  }
});
