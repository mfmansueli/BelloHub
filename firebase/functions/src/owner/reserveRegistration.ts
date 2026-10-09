import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import { ensureAccountExists } from '../lib/account.js';
import { bumpCalendarLock, readCalendarLock } from '../lib/calendar.js';
import type { AccountDoc } from '../lib/docs.js';
import { consumeRate } from '../lib/rateLimit.js';
import { applyRegistrations, readRegistrationState } from '../lib/registrations.js';
import { FREE_REGISTRATION_LIMIT } from '../lib/rules.js';
import { dataOf, refs, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * D42: the account-level counter of client registrations. Idempotent by client id and by phone; counts the first time
 * only; refuses (without counting) once the free registrations are used and there is no plan. The client app reads the
 * answer, it never writes the counter.
 */
export const reserveRegistration = defineUseCase({
  name: 'reserveRegistration',
  access: 'owner',
  ...contract.reserveRegistration,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    await ensureAccountExists(deps, uid, ctx);

    const outcome = await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const account = dataOf<AccountDoc>(await reader.doc(refs(deps.db).account(uid)));
      if (!account) throw new Error('account vanished');
      await readCalendarLock(tx, deps.db, uid);
      const reads = await readRegistrationState(reader, deps, uid, [input]);
      const { results, count } = applyRegistrations(tx, deps, uid, account, reads, [input]);
      bumpCalendarLock(tx, deps.db, uid);
      return { result: results[0], count };
    });
    if (!outcome.result) throw new Error('no result');
    deps.log.info('registration.reserve', { uid, decision: outcome.result.decision, count: outcome.count });
    return {
      decision: outcome.result.decision,
      count: outcome.count,
      freeLimit: FREE_REGISTRATION_LIMIT,
      alreadyCounted: outcome.result.alreadyCounted
    };
  }
});
