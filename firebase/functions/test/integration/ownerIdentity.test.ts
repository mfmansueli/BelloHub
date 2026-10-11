import { randomUUID } from 'node:crypto';

import { beforeEach, describe, expect, it } from 'vitest';

import type { AccountDoc } from '../../src/lib/docs.js';
import { refs } from '../../src/lib/store.js';
import { claimSlug } from '../../src/owner/claimSlug.js';
import { deleteAccount } from '../../src/owner/deleteAccount.js';
import { ensureAccount } from '../../src/owner/ensureAccount.js';
import { publishAvailability } from '../../src/owner/publishAvailability.js';
import { publishProfile } from '../../src/owner/publishProfile.js';
import { registerDevice } from '../../src/owner/registerDevice.js';
import { reserveRegistration } from '../../src/owner/reserveRegistration.js';
import { updateInboxKey } from '../../src/owner/updateInboxKey.js';
import { getPublicPage } from '../../src/public/getPublicPage.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { mariaAvailability, mariaProfile, newInboxKey } from '../support/seed.js';

// D44: the professional signs in with Apple. Her ID token then carries no phone number: no owner function may need one.
// `{ uid }` alone is what the gate hands a use case for an Apple sign-in; `{ uid, authPhone }` is the phone sign-in.

const env = createTestEnv();
const APPLE_UID = 'apple-owner';
const apple = { uid: APPLE_UID };
const phone = { uid: 'phone-owner', authPhone: '+5511900000000' };
const CODE = 'c9f2e1d0b7a6.0.rrrr.a-fresh-authorization-code';

beforeEach(async () => {
  await resetEmulators(env, { storage: true, auth: true });
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  env.apple.outcome = 'revoked';
  env.apple.codes.length = 0;
});

async function account(uid: string): Promise<AccountDoc | undefined> {
  return (await refs(env.deps.db).account(uid).get()).data() as AccountDoc | undefined;
}

describe('an owner signed in with Apple (no phone on the token)', () => {
  it('creates her account without a phone and runs every setup call', async () => {
    const created = (await env.call(ensureAccount, { countryCode: 'PT', locale: 'pt-PT' }, apple)) as { uid: string };
    expect(created.uid).toBe(APPLE_UID);
    expect(await account(APPLE_UID)).toMatchObject({ countryCode: 'PT', locale: 'pt-PT' });
    expect((await account(APPLE_UID))?.phone).toBeUndefined();

    const key = newInboxKey();
    expect(await env.call(claimSlug, { slug: 'joana' }, apple)).toEqual({ slug: 'joana' });
    expect(await env.call(publishProfile, { profile: mariaProfile(key, { displayName: 'Joana' }) }, apple)).toMatchObject({ slug: 'joana' });
    expect(await env.call(publishAvailability, mariaAvailability(), apple)).toMatchObject({ updatedAt: expect.any(String) as string });
    expect(await env.call(updateInboxKey, { inboxKey: newInboxKey() }, apple)).toMatchObject({ keyring: expect.any(Array) as unknown[] });
    expect(await env.call(registerDevice, { fcmToken: `fcm-${'a'.repeat(60)}`, platform: 'ios' }, apple)).toEqual({ ok: true });
    expect(await env.call(reserveRegistration, { clientId: randomUUID() }, apple)).toMatchObject({ decision: 'allowed', count: 1 });
    expect(await env.call(getPublicPage, { slug: 'joana' })).toMatchObject({ profile: { displayName: 'Joana' } });
  });

  it('keeps the phone of a phone sign-in on the account, and only then', async () => {
    await env.call(ensureAccount, { countryCode: 'BR', locale: 'pt-BR' }, phone);
    await env.call(ensureAccount, { countryCode: 'PT', locale: 'pt-PT' }, apple);

    expect((await account(phone.uid))?.phone).toBe('+5511900000000');
    expect((await account(APPLE_UID))?.phone).toBeUndefined();
  });

  it('revokes the Apple grant on deletion when the app sends a fresh authorization code', async () => {
    await env.call(ensureAccount, { countryCode: 'PT', locale: 'pt-PT' }, apple);
    await env.deps.auth.createUser({ uid: APPLE_UID, email: 'x@privaterelay.appleid.com' });

    const result = await env.call(deleteAccount, { confirm: true, appleAuthorizationCode: CODE }, apple);

    expect(result).toEqual({ ok: true, appleRevocation: 'revoked' });
    expect(env.apple.codes).toEqual([CODE]);
    expect(await account(APPLE_UID)).toBeUndefined();
    await expect(env.deps.auth.getUser(APPLE_UID)).rejects.toMatchObject({ code: 'auth/user-not-found' });
    expect(JSON.stringify(env.logs.entries)).not.toContain(CODE);
  });

  it('still deletes everything when Apple refuses, and says so', async () => {
    await env.call(ensureAccount, { countryCode: 'PT', locale: 'pt-PT' }, apple);
    env.apple.outcome = 'failed';

    const result = await env.call(deleteAccount, { confirm: true, appleAuthorizationCode: CODE }, apple);

    expect(result).toEqual({ ok: true, appleRevocation: 'failed' });
    expect(await account(APPLE_UID)).toBeUndefined();
  });

  it('skips the revocation without a code (a phone sign-in has nothing to revoke) and rejects a code that cannot be real', async () => {
    await env.call(ensureAccount, { countryCode: 'BR', locale: 'pt-BR' }, phone);

    expect(await env.call(deleteAccount, { confirm: true }, phone)).toEqual({ ok: true, appleRevocation: 'skipped' });
    expect(env.apple.codes).toEqual([]);
    await expect(env.call(deleteAccount, { confirm: true, appleAuthorizationCode: 'short' }, apple)).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });
});
