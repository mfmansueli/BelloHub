import { randomUUID } from 'node:crypto';

import { beforeEach, describe, expect, it } from 'vitest';

import { refs, ts } from '../../src/lib/store.js';
import { deleteClientServerData } from '../../src/owner/deleteClientServerData.js';
import { ensureAccount } from '../../src/owner/ensureAccount.js';
import { reserveRegistration } from '../../src/owner/reserveRegistration.js';
import { reserveRegistrations } from '../../src/owner/reserveRegistrations.js';
import { ANA, asBooked, book } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { ownerContext, seedProfessional } from '../support/seed.js';
import type { Professional } from '../support/seed.js';

// D42: the first 10 client registrations are free, counted on the server, never given back by a delete, and a client is
// counted once however she arrives (the same client id, or the same phone).

const env = createTestEnv();
let pro: Professional;
const who = () => ownerContext(pro.uid);

beforeEach(async () => {
  await resetEmulators(env);
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  pro = await seedProfessional(env);
});

interface Reservation {
  decision: 'allowed' | 'needsSubscription';
  count: number;
  freeLimit: number;
  alreadyCounted: boolean;
}

const reserve = async (clientId = randomUUID(), phone?: string): Promise<Reservation> =>
  (await env.call(reserveRegistration, { clientId, ...(phone ? { phone } : {}) }, who())) as Reservation;

const phoneOf = (n: number): string => `+55119000${String(n).padStart(5, '0')}`;

async function accountDoc() {
  return (await refs(env.deps.db).account(pro.uid).get()).data() as { registrations: { count: number; freeLimit: number }; plan: { state: string } };
}

describe('ensureAccount', () => {
  it('creates the account once and returns what the app needs', async () => {
    const first = (await env.call(ensureAccount, { countryCode: 'BR', locale: 'pt-BR' }, who())) as {
      uid: string; appAccountToken: string; dataRegion: string; registrations: { count: number; freeLimit: number }; plan: { state: string }; slug?: string;
    };
    const second = (await env.call(ensureAccount, { countryCode: 'BR', locale: 'pt-BR' }, who())) as typeof first;

    expect(first).toMatchObject({ uid: pro.uid, dataRegion: 'eu', registrations: { count: 0, freeLimit: 10 }, plan: { state: 'none' }, slug: 'maria' });
    expect(first.appAccountToken).toMatch(/^[0-9a-f-]{36}$/);
    expect(second.appAccountToken).toBe(first.appAccountToken);
  });

  it('fills in the country on an account that an earlier call created before it was known', async () => {
    const early = ownerContext('pro-early');
    await env.call(reserveRegistration, { clientId: randomUUID() }, early);

    await env.call(ensureAccount, { countryCode: 'PT', locale: 'pt-PT' }, early);

    const stored = (await refs(env.deps.db).account('pro-early').get()).data();
    expect(stored).toMatchObject({ countryCode: 'PT', locale: 'pt-PT' });
  });

  it('needs a signed-in professional', async () => {
    await expect(env.call(ensureAccount, { countryCode: 'BR', locale: 'pt-BR' })).rejects.toMatchObject({ code: 'UNAUTHENTICATED' });
  });
});

describe('reserveRegistration', () => {
  it('counts the first ten clients and refuses the eleventh without counting it', async () => {
    for (let n = 1; n <= 10; n += 1) {
      const result = await reserve(randomUUID(), phoneOf(n));
      expect(result).toMatchObject({ decision: 'allowed', count: n, alreadyCounted: false });
    }

    const eleventh = await reserve(randomUUID(), phoneOf(11));

    expect(eleventh).toMatchObject({ decision: 'needsSubscription', count: 10, freeLimit: 10, alreadyCounted: false });
    expect((await accountDoc()).registrations.count).toBe(10);
    expect((await refs(env.deps.db).registrations(pro.uid).get()).size).toBe(10);
  });

  it('never counts the same client id twice, however often the app asks', async () => {
    const clientId = randomUUID();

    const first = await reserve(clientId, phoneOf(1));
    const again = await reserve(clientId, phoneOf(1));
    const withoutPhone = await reserve(clientId);

    expect(first.alreadyCounted).toBe(false);
    expect(again).toMatchObject({ decision: 'allowed', count: 1, alreadyCounted: true });
    expect(withoutPhone).toMatchObject({ count: 1, alreadyCounted: true });
  });

  it('never counts the same phone twice, even under another client id', async () => {
    await reserve(randomUUID(), phoneOf(1));

    const other = await reserve(randomUUID(), phoneOf(1));

    expect(other).toMatchObject({ decision: 'allowed', count: 1, alreadyCounted: true });
    expect((await accountDoc()).registrations.count).toBe(1);
  });

  it('still allows a duplicate phone or id after the free registrations are used', async () => {
    const known = randomUUID();
    await reserve(known, phoneOf(1));
    for (let n = 2; n <= 10; n += 1) await reserve(randomUUID(), phoneOf(n));

    expect(await reserve(known)).toMatchObject({ decision: 'allowed', alreadyCounted: true, count: 10 });
    expect(await reserve(randomUUID(), phoneOf(3))).toMatchObject({ decision: 'allowed', alreadyCounted: true, count: 10 });
    expect(await reserve(randomUUID(), phoneOf(40))).toMatchObject({ decision: 'needsSubscription' });
  });

  it('counts the clients who booked through the link: the same phone is not counted again by the app', async () => {
    const booked = asBooked(await book(env, pro));
    expect(booked.status).toBe('confirmed');
    expect((await accountDoc()).registrations.count).toBe(1);

    const fromApp = await reserve(randomUUID(), ANA.phone);

    expect(fromApp).toMatchObject({ decision: 'allowed', count: 1, alreadyCounted: true });
  });

  it('does not give a slot back when a client is deleted (the ledger and the count stay)', async () => {
    const clientId = randomUUID();
    await reserve(clientId, phoneOf(1));
    for (let n = 2; n <= 10; n += 1) await reserve(randomUUID(), phoneOf(n));

    await env.call(deleteClientServerData, { phone: phoneOf(1) }, who());

    expect((await accountDoc()).registrations.count).toBe(10);
    expect((await refs(env.deps.db).registrations(pro.uid).get()).size).toBe(10);
    expect(await reserve(randomUUID(), phoneOf(50))).toMatchObject({ decision: 'needsSubscription' });
    // The same client id is still known to the ledger: a retry does not count again.
    expect(await reserve(clientId)).toMatchObject({ decision: 'allowed', alreadyCounted: true });
  });

  it('lets registrations continue without limit while she has a plan, and keeps counting', async () => {
    await refs(env.deps.db).account(pro.uid).update({ 'registrations.count': 10, plan: { state: 'active', expiresAt: ts(env.clock.now() + 86_400_000), source: 'appStore' } });

    expect(await reserve(randomUUID(), phoneOf(11))).toMatchObject({ decision: 'allowed', count: 11 });
    expect(await reserve(randomUUID(), phoneOf(12))).toMatchObject({ decision: 'allowed', count: 12 });
  });

  it('applies the limit again after the plan lapses, and never removes an existing client', async () => {
    await refs(env.deps.db).account(pro.uid).update({ 'registrations.count': 12, plan: { state: 'active', expiresAt: ts(env.clock.now() + 1000), source: 'appStore' } });
    env.clock.advance(2000);

    expect(await reserve(randomUUID(), phoneOf(13))).toMatchObject({ decision: 'needsSubscription', count: 12 });
  });

  it('stays at ten when twelve clients are registered at the same moment', async () => {
    const results = await Promise.all(Array.from({ length: 12 }, (_, n) => reserve(randomUUID(), phoneOf(n + 1))));

    expect(results.filter((result) => result.decision === 'allowed')).toHaveLength(10);
    expect(results.filter((result) => result.decision === 'needsSubscription')).toHaveLength(2);
    expect((await accountDoc()).registrations.count).toBe(10);
  }, 60_000);

  it('cannot be reached by another professional or an anonymous caller', async () => {
    await expect(env.call(reserveRegistration, { clientId: randomUUID() })).rejects.toMatchObject({ code: 'UNAUTHENTICATED' });
    await reserve(randomUUID(), phoneOf(1));
    const other = ownerContext('someone-else');
    const theirs = (await env.call(reserveRegistration, { clientId: randomUUID(), phone: phoneOf(1) }, other)) as Reservation;

    expect(theirs).toMatchObject({ decision: 'allowed', count: 1, alreadyCounted: false });
    expect((await accountDoc()).registrations.count).toBe(1);
  });
});

describe('reserveRegistrations (an import)', () => {
  it('registers in order and stops at the limit, answering needsSubscription for the rest', async () => {
    for (let n = 1; n <= 7; n += 1) await reserve(randomUUID(), phoneOf(n));
    const clients = Array.from({ length: 6 }, (_, n) => ({ clientId: randomUUID(), phone: phoneOf(100 + n) }));

    const result = (await env.call(reserveRegistrations, { clients }, who())) as {
      results: { decision: string; alreadyCounted: boolean }[]; count: number;
    };

    expect(result.results.map((entry) => entry.decision)).toEqual(['allowed', 'allowed', 'allowed', 'needsSubscription', 'needsSubscription', 'needsSubscription']);
    expect(result.count).toBe(10);
    expect((await accountDoc()).registrations.count).toBe(10);
  });

  it('counts a repeated phone or id inside one import once', async () => {
    const sameId = randomUUID();
    const result = (await env.call(reserveRegistrations, {
      clients: [
        { clientId: sameId, phone: phoneOf(1) },
        { clientId: sameId, phone: phoneOf(1) },
        { clientId: randomUUID(), phone: phoneOf(1) },
        { clientId: randomUUID(), phone: phoneOf(2) }
      ]
    }, who())) as { results: { alreadyCounted: boolean }[]; count: number };

    expect(result.results.map((entry) => entry.alreadyCounted)).toEqual([false, true, true, false]);
    expect(result.count).toBe(2);
  });

  it('accepts at most 200 clients', async () => {
    const clients = Array.from({ length: 201 }, () => ({ clientId: randomUUID() }));

    await expect(env.call(reserveRegistrations, { clients }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });
});
