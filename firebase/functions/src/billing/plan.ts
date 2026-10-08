import type { PlanState, StoredPlan } from '../lib/rules.js';
import type { VerifiedTransaction } from './AppStoreVerifier.js';

export interface PlanFromStore {
  state: PlanState;
  expiresAt?: number | undefined;
}

/** What a verified StoreKit transaction means for the account (D33). A refund or revoke wins over everything. */
export function planFromTransaction(tx: VerifiedTransaction, now: number): PlanFromStore {
  if (tx.revokedAt !== undefined && tx.revokedAt <= now) return { state: 'revoked', expiresAt: tx.revokedAt };
  if (tx.expiresAt !== undefined && tx.expiresAt > now) return { state: 'active', expiresAt: tx.expiresAt };
  if (tx.gracePeriodExpiresAt !== undefined && tx.gracePeriodExpiresAt > now) {
    return { state: 'grace', expiresAt: tx.gracePeriodExpiresAt };
  }
  return { state: 'expired', expiresAt: tx.expiresAt };
}

/**
 * Whether `candidate` should replace `current`. A stale transaction (the app replaying an old receipt, or a delayed
 * notification) must not lower a plan that runs longer; a revoke always applies.
 */
export function shouldReplacePlan(current: StoredPlan, candidate: PlanFromStore): boolean {
  if (candidate.state === 'revoked') return true;
  if (current.state === 'none') return true;
  const currentEnd = current.expiresAt ?? 0;
  const candidateEnd = candidate.expiresAt ?? 0;
  return candidateEnd >= currentEnd;
}
