import { randomUUID } from 'node:crypto';

import { beforeAll, describe, expect, it } from 'vitest';

import { refs } from '../../src/lib/store.js';
import { respondBookingRequest } from '../../src/owner/respondBookingRequest.js';
import { reserveRegistration } from '../../src/owner/reserveRegistration.js';
import { getPublicPage } from '../../src/public/getPublicPage.js';
import { ensureAccount } from '../../src/owner/ensureAccount.js';
import { asBooked, BIA, book } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { ownerContext, seedProfessional } from '../support/seed.js';
import type { Professional } from '../support/seed.js';

// The gate every callable passes (access level, App Check, strict input, output schema) and the D42 races that need two
// different use cases to run at the same moment.

const strict = createTestEnv({ enforceAppCheck: true });
const open = createTestEnv();
let pro: Professional;

beforeAll(async () => {
  await resetEmulators(open);
  pro = await seedProfessional(open);
});

describe('App Check enforcement (a deploy parameter, H5)', () => {
  it('rejects a call without a valid token when enforcement is on, and serves it when the token is there', async () => {
    await expect(strict.call(getPublicPage, { slug: pro.slug }, { appCheck: false })).rejects.toMatchObject({ code: 'APP_CHECK_REQUIRED' });
    expect(await strict.call(getPublicPage, { slug: pro.slug }, { appCheck: true })).toMatchObject({ profile: { slug: pro.slug } });
  });

  it('applies to owner functions too, after the sign-in check', async () => {
    await expect(strict.call(ensureAccount, { countryCode: 'BR', locale: 'pt-BR' }, { appCheck: false })).rejects.toMatchObject({ code: 'UNAUTHENTICATED' });
    await expect(strict.call(ensureAccount, { countryCode: 'BR', locale: 'pt-BR' }, { uid: pro.uid, appCheck: false })).rejects.toMatchObject({ code: 'APP_CHECK_REQUIRED' });
  });

  it('accepts a missing token while enforcement is off (the default until staging passes)', async () => {
    expect(await open.call(getPublicPage, { slug: pro.slug }, { appCheck: false })).toMatchObject({ profile: { slug: pro.slug } });
  });
});

describe('the gate', () => {
  it('turns anything unexpected into INTERNAL with no detail', async () => {
    const original = open.deps.db;
    // A use case that throws something that is not an AppError must not leak its message.
    const failing = { ...getPublicPage, handle: () => Promise.reject(new Error('secret Ana Costa +5511987654321')) };
    const error = await open.call(failing, { slug: pro.slug }).catch((caught: unknown) => caught);

    expect(error).toMatchObject({ code: 'INTERNAL' });
    expect(JSON.stringify(error)).not.toContain('Ana');
    expect(JSON.stringify(open.logs.entries)).not.toContain('Ana Costa');
    expect(open.deps.db).toBe(original);
  });

  it('refuses a response that does not match its schema (caught in tests and in the emulator)', async () => {
    const wrong = { ...getPublicPage, handle: () => Promise.resolve({ profile: 'nope' }) };

    await expect(open.call(wrong as never, { slug: pro.slug })).rejects.toMatchObject({ code: 'INTERNAL' });
  });
});

describe('free registrations (D42) under concurrency across different use cases', () => {
  it('counts a phone once when the booking page and the app register it at the same moment', async () => {
    await resetEmulators(open);
    pro = await seedProfessional(open);

    const results = await Promise.all([
      open.call(reserveRegistration, { clientId: randomUUID(), phone: '+5511987654321' }, ownerContext(pro.uid)),
      book(open, pro, { startsAt: '2026-10-02T13:00:00.000Z' })
    ]);

    expect(asBooked(results[1] as never).status).toBe('confirmed');
    const account = (await refs(open.deps.db).account(pro.uid).get()).data() as { registrations: { count: number } };
    expect(account.registrations.count).toBe(1);
  }, 60_000);

  it('approves only one of two requests at the ninth registration when she approves both at once', async () => {
    await resetEmulators(open);
    pro = await seedProfessional(open);
    await refs(open.deps.db).profile(pro.slug).update({ 'booking.requiresApproval': true });
    const first = asBooked(await book(open, pro, { startsAt: '2026-10-02T12:00:00.000Z' }));
    const second = asBooked(await book(open, pro, { client: BIA, startsAt: '2026-10-02T17:00:00.000Z' }));
    await refs(open.deps.db).account(pro.uid).update({ 'registrations.count': 9 });

    const answers = await Promise.all([
      open.call(respondBookingRequest, { bookingId: first.bookingId, decision: 'approve' }, ownerContext(pro.uid)),
      open.call(respondBookingRequest, { bookingId: second.bookingId, decision: 'approve' }, ownerContext(pro.uid))
    ]);

    expect(answers.map((answer) => (answer as { status: string }).status).sort()).toEqual(['confirmed', 'needsSubscription']);
    const account = (await refs(open.deps.db).account(pro.uid).get()).data() as { registrations: { count: number } };
    expect(account.registrations.count).toBe(10);
  }, 60_000);
});
