import type { Deps } from '../app/Deps.js';
import { planFromTransaction, shouldReplacePlan } from '../billing/plan.js';
import { isAppError } from '../lib/errors.js';
import type { AccountDoc } from '../lib/docs.js';
import { C } from '../lib/docs.js';
import { msOpt, ts } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * App Store Server Notifications V2 (docs/11 section 3): verify Apple's signed payload, find the account by the
 * `appAccountToken` the app set at purchase, and mirror the plan. Returns the HTTP status to answer Apple with: 200 when
 * handled or deliberately ignored, 503 when the verifier is not set up or the check must be retried (Apple retries), 400 for
 * an unverifiable payload.
 */
export async function handleAppStoreNotification(deps: Deps, signedPayload: unknown): Promise<200 | 400 | 503> {
  if (typeof signedPayload !== 'string' || signedPayload.length < 20) return 400;
  let notification;
  try {
    notification = await deps.appStore.verifyNotification(signedPayload);
  } catch (error) {
    // 503 makes Apple retry: no verifier yet, or a verification that failed for a reason Apple calls retryable.
    return isAppError(error) && (error.code === 'NOT_CONFIGURED' || error.code === 'TRY_AGAIN') ? 503 : 400;
  }
  const transaction = notification.transaction;
  if (!transaction?.appAccountToken || !deps.settings.planProductIds.includes(transaction.productId)) return 200;

  const matches = await deps.db
    .collection(C.accounts)
    .where('appAccountToken', '==', transaction.appAccountToken.toLowerCase())
    .limit(1)
    .get();
  const account = matches.docs[0];
  if (!account) return 200;

  const now = deps.now();
  const candidate = planFromTransaction(transaction, now);
  await runTransaction(deps.db, async (tx) => {
    const current = (await tx.get(account.ref)).data() as AccountDoc | undefined;
    if (!current) return;
    if (!shouldReplacePlan({ state: current.plan.state, expiresAt: msOpt(current.plan.expiresAt) }, candidate)) return;
    tx.update(account.ref, {
      plan: {
        state: candidate.state,
        source: 'appStore',
        ...(candidate.expiresAt !== undefined ? { expiresAt: ts(candidate.expiresAt) } : {})
      },
      updatedAt: ts(now)
    });
  });
  deps.log.info('plan.notification', { ownerUid: account.id, kind: notification.type, status: candidate.state });
  return 200;
}
