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

/** `reserveRegistration` for an import: processed in order, so it stops counting at the limit and refuses the rest. */
export const reserveRegistrations = defineUseCase({
  name: 'reserveRegistrations',
  access: 'owner',
  ...contract.reserveRegistrations,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    await ensureAccountExists(deps, uid, ctx);

    const outcome = await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const account = dataOf<AccountDoc>(await reader.doc(refs(deps.db).account(uid)));
      if (!account) throw new Error('account vanished');
      await readCalendarLock(tx, deps.db, uid);
      const reads = await readRegistrationState(reader, deps, uid, input.clients);
      const applied = applyRegistrations(tx, deps, uid, account, reads, input.clients);
      bumpCalendarLock(tx, deps.db, uid);
      return applied;
    });
    deps.log.info('registration.reserveMany', { uid, count: outcome.count, rows: input.clients.length });
    return { results: outcome.results, count: outcome.count, freeLimit: FREE_REGISTRATION_LIMIT };
  }
});
