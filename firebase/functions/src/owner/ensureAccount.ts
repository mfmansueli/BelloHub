import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import { UNKNOWN_COUNTRY, ensureAccountExists } from '../lib/account.js';
import { consumeRate } from '../lib/rateLimit.js';
import { msOpt, refs, ts } from '../lib/store.js';
import { FREE_REGISTRATION_LIMIT } from '../lib/rules.js';

/** Creates the professional's server account on first call and returns what the app needs to start. Idempotent. */
export const ensureAccount = defineUseCase({
  name: 'ensureAccount',
  access: 'owner',
  ...contract.ensureAccount,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    let account = await ensureAccountExists(deps, uid, ctx);
    // An account made by an earlier call that did not know the country yet gets it now.
    if (account.countryCode === UNKNOWN_COUNTRY) {
      account = { ...account, countryCode: input.countryCode, locale: input.locale };
      await refs(deps.db)
        .account(uid)
        .update({ countryCode: input.countryCode, locale: input.locale, updatedAt: ts(deps.now()) });
    }
    const expiresAt = msOpt(account.plan.expiresAt);
    return {
      uid,
      appAccountToken: account.appAccountToken,
      dataRegion: account.dataRegion,
      registrations: { count: account.registrations.count, freeLimit: FREE_REGISTRATION_LIMIT },
      plan: { state: account.plan.state, ...(expiresAt !== undefined ? { expiresAt: iso(expiresAt) } : {}) },
      ...(account.slug ? { slug: account.slug } : {})
    };
  }
});
