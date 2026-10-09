import type { Deps } from '../app/Deps.js';
import type { CallContext } from '../app/UseCase.js';
import type { LocaleId } from '../contracts/common.js';
import type { AccountDoc } from './docs.js';
import { FREE_REGISTRATION_LIMIT } from './rules.js';
import { dataOf, refs, ts } from './store.js';

/** Placeholder until `ensureAccount` tells us the real country. Offline queues replay in any order, so any owner call may come first. */
export const UNKNOWN_COUNTRY = 'ZZ';

export function newAccount(deps: Deps, ctx: CallContext, countryCode: string, locale: LocaleId): AccountDoc {
  const now = ts(deps.now());
  return {
    schemaVersion: 1,
    ...(ctx.authPhone ? { phone: ctx.authPhone } : {}),
    countryCode,
    locale,
    dataRegion: 'eu',
    plan: { state: 'none' },
    registrations: { count: 0, freeLimit: FREE_REGISTRATION_LIMIT },
    inboxKeyring: [],
    deletion: {},
    appAccountToken: deps.random.uuid(),
    createdAt: now,
    updatedAt: now
  };
}

/**
 * Makes sure `accounts/{uid}` exists before a transaction that updates it. Idempotent and safe to race: an
 * "already exists" from a concurrent first call is the success we wanted. Returns the account as it is now.
 */
export async function ensureAccountExists(deps: Deps, uid: string, ctx: CallContext): Promise<AccountDoc> {
  const ref = refs(deps.db).account(uid);
  const existing = dataOf<AccountDoc>(await ref.get());
  if (existing) return existing;
  const account = newAccount(deps, ctx, UNKNOWN_COUNTRY, 'en');
  try {
    await ref.create(account);
    return account;
  } catch (error) {
    const code = (error as { code?: unknown }).code;
    if (code !== 6 && code !== 'already-exists') throw error;
    const winner = dataOf<AccountDoc>(await ref.get());
    if (!winner) throw error;
    return winner;
  }
}
