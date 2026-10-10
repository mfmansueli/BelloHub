import { randomBytes, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { getAuth } from 'firebase-admin/auth';
import { beforeAll, describe, expect, it } from 'vitest';

import { USE_CASES } from '../../src/app/registry.js';
import { base64url } from '../../src/lib/crypto.js';
import { C } from '../../src/lib/docs.js';
import { adminApp, clearAuth, clearFirestore, testFirestore } from '../support/emulator.js';
import { mariaAvailability, mariaProfile, newInboxKey, SERVICE } from '../support/seed.js';
import { callFunction, callOk, FUNCTIONS_BASE, signInProfessional, signInWithApple, signInWithPhone, waitUntil } from '../support/transport.js';

// The deployed entry points, through the Functions emulator, with the callable wire protocol of API.md section 1.

const ORIGIN = 'https://bellohub.app';
const CLIENT_PHONE = '+5511987654321';
const db = testFirestore();

let ownerToken = '';
let slug = '';
let inboxKey = newInboxKey();

/** The first working Tuesday of the booking window, 10:00 in Sao Paulo, whatever day the suite runs. */
function nextTuesday10(): { date: string; instant: string } {
  const probe = new Date(Date.now() + 5 * 86_400_000);
  while (probe.getUTCDay() !== 2) probe.setUTCDate(probe.getUTCDate() + 1);
  const date = probe.toISOString().slice(0, 10);
  return { date, instant: `${date}T13:00:00.000Z` };
}

beforeAll(async () => {
  await clearFirestore();
  await clearAuth();
  const uid = 'transport-owner';
  await getAuth(adminApp()).createUser({ uid, phoneNumber: '+5511900000000' });
  ownerToken = await signInProfessional(await getAuth(adminApp()).createCustomToken(uid));
  slug = `maria-${randomBytes(3).toString('hex')}`;
  inboxKey = newInboxKey();
  await callOk('ensureAccount', { countryCode: 'BR', locale: 'pt-BR' }, { idToken: ownerToken });
  await callOk('claimSlug', { slug }, { idToken: ownerToken });
  await callOk('publishProfile', { profile: mariaProfile(inboxKey, { intake: { formVersion: 1, template: { questions: [] } } }) }, { idToken: ownerToken });
  await callOk('publishAvailability', mariaAvailability(), { idToken: ownerToken });
  await callOk('registerDevice', { fcmToken: `fcm-${'t'.repeat(60)}`, platform: 'ios' }, { idToken: ownerToken });
}, 120_000);

describe('every deployed function answers in the callable protocol', () => {
  // One worker per function starts the first time it is called (about four seconds each in the emulator), so the
  // wiring check covers one function of every kind; the rest are covered by the journeys below, by the export list
  // test in test/unit/contracts.test.ts and by the emulator's own "Loaded functions definitions" line.
  const SAMPLE = ['getPublicPage', 'getSlots', 'createBooking', 'getBooking', 'submitSealed', 'ensureAccount', 'reserveRegistration', 'deleteAccount'];

  it.each(SAMPLE)('%s rejects an empty call with a stable code', async (name) => {
    const useCase = USE_CASES.find((candidate) => candidate.name === name);
    const result = await callFunction(name, {});

    expect(result.status, name).toBeGreaterThanOrEqual(400);
    expect(result.status, name).toBeLessThan(500);
    expect(result.code, name).toBe(useCase?.access === 'owner' ? 'UNAUTHENTICATED' : 'INVALID_ARGUMENT');
  }, 60_000);

  it('never echoes input values or stack traces in an error', async () => {
    const result = await callFunction('createBooking', { slug, client: { name: 'Zuleika Quasimodo', phone: 'nope', health: 'latex allergy' } });

    expect(result.code).toBe('INVALID_ARGUMENT');
    expect(JSON.stringify(result)).not.toMatch(/Zuleika|latex|stack|at .*\.js/);
    expect(result.details).toEqual({ fields: expect.arrayContaining(['client.phone', 'client.health']) as string[] });
  });
});

describe('the whole booking journey, as the web app makes it', () => {
  const { date, instant } = nextTuesday10();

  it('reads the page, finds a slot, books it with a phone verified through the Auth emulator, and manages it', async () => {
    const page = await callOk<{ profile: { slug: string; inboxKey: { keyId: string } }; intakeAvailable: boolean }>('getPublicPage', { slug }, { origin: ORIGIN });
    expect(page.profile.slug).toBe(slug);
    expect(page.profile.inboxKey.keyId).toBe(inboxKey.keyId);
    expect(page.intakeAvailable).toBe(true);

    // D56: 10:00 leaves a 60 minute gap before it (her shortest offer needs 75), so it sits behind "Show all times".
    const slots = await callOk<{ days: { slots: string[]; more?: string[] }[] }>('getSlots', { slug, serviceId: SERVICE.glowFacial, from: date, to: date });
    expect(slots.days[0]?.more).toContain(instant);

    const idToken = await signInWithPhone(CLIENT_PHONE);
    const booked = await callOk<{ status: string; manageToken: string; bookingId: string }>('createBooking', {
      slug, serviceId: SERVICE.glowFacial, startsAt: instant,
      client: { name: 'Ana Costa', phone: CLIENT_PHONE, locale: 'pt-BR' },
      verification: { method: 'phone', idToken }, idempotencyKey: randomUUID()
    });
    expect(booked.status).toBe('confirmed');

    const view = await callOk<{ status: string; professional: { displayName: string }; actions: { cancel: string } }>('getBooking', { token: booked.manageToken });
    expect(view).toMatchObject({ status: 'confirmed', professional: { displayName: 'Maria Souza' }, actions: { cancel: 'free' } });

    const ics = await fetch(`${FUNCTIONS_BASE}/getIcs?token=${booked.manageToken}&locale=pt-BR`);
    expect(ics.status).toBe(200);
    expect(ics.headers.get('content-type')).toContain('text/calendar');
    expect(ics.headers.get('cache-control')).toBe('no-store');
    const body = await ics.text();
    expect(body).toContain('BEGIN:VEVENT');
    expect(body).toContain(`DTSTART:${instant.replaceAll('-', '').replaceAll(':', '').replace('.000', '')}`);

    const after = await callOk<{ days: { slots: string[]; more?: string[] }[] }>('getSlots', { slug, serviceId: SERVICE.glowFacial, from: date, to: date });
    expect([...(after.days[0]?.slots ?? []), ...(after.days[0]?.more ?? [])]).not.toContain(instant);
    const second = await callOk<{ status: string }>('createBooking', {
      slug, serviceId: SERVICE.glowFacial, startsAt: instant,
      client: { name: 'Bia Lima', phone: '+5511976543210', locale: 'pt-BR' },
      verification: { method: 'phone', idToken: await signInWithPhone('+5511976543210') }, idempotencyKey: randomUUID()
    });
    expect(second.status).toBe('slotTaken');

    const cancelled = await callOk<{ status: string }>('cancelBooking', { token: booked.manageToken });
    expect(cancelled.status).toBe('cancelled');
  }, 120_000);

  it('refuses a booking whose phone token belongs to another number', async () => {
    const idToken = await signInWithPhone('+5511911112222');

    const result = await callFunction('createBooking', {
      slug, serviceId: SERVICE.glowFacial, startsAt: instant,
      client: { name: 'Ana Costa', phone: CLIENT_PHONE, locale: 'pt-BR' },
      verification: { method: 'phone', idToken }, idempotencyKey: randomUUID()
    });

    expect(result.status).toBe(403);
    expect(result.code).toBe('VERIFICATION_FAILED');
  }, 60_000);

  it('uses the fixed code of the emulator for the email path (the test hook), then books with the proof', async () => {
    const send = await callFunction('sendEmailCode', { slug, email: 'ana@example.com', locale: 'pt-BR', purpose: 'booking' });
    expect(send.status).toBe(200);
    const verified = await callOk<{ proof: string }>('verifyEmailCode', { email: 'ana@example.com', code: '123456' });

    const booked = await callOk<{ status: string; emailSent: boolean }>('createBooking', {
      slug, serviceId: SERVICE.brazilianGlow, startsAt: '2026-12-01T17:00:00.000Z'.replace('2026-12-01', date),
      client: { name: 'Ana Costa', phone: CLIENT_PHONE, email: 'ana@example.com', locale: 'pt-BR' },
      verification: { method: 'email', proof: verified.proof }, idempotencyKey: randomUUID()
    });

    expect(booked.status).toBe('confirmed');
    expect(booked.emailSent).toBe(true);
  }, 60_000);
});

describe('the professional signs in with Apple or by phone (D44)', () => {
  it('accepts an Apple-provider ID token with no phone number for every owner call, and deletes the account with it', async () => {
    const { idToken, uid } = await signInWithApple('001234.apple-subject.5678', 'joana@privaterelay.appleid.com');
    const user = await getAuth(adminApp()).getUser(uid);
    expect(user.phoneNumber).toBeUndefined();
    expect(user.providerData.map((provider) => provider.providerId)).toEqual(['apple.com']);

    const created = await callOk<{ uid: string }>('ensureAccount', { countryCode: 'PT', locale: 'pt-PT' }, { idToken });
    expect(created.uid).toBe(uid);
    expect((await db.collection(C.accounts).doc(uid).get()).data()?.phone).toBeUndefined();
    await callOk('claimSlug', { slug: `joana-${randomBytes(3).toString('hex')}` }, { idToken });
    await callOk('registerDevice', { fcmToken: `fcm-${'j'.repeat(60)}`, platform: 'ios' }, { idToken });

    const deleted = await callOk<{ ok: true; appleRevocation: string }>('deleteAccount', { confirm: true, appleAuthorizationCode: 'c1a2b3.0.rrrr.authorization-code' }, { idToken });
    expect(deleted).toEqual({ ok: true, appleRevocation: 'skipped' });
    expect((await db.collection(C.accounts).doc(uid).get()).exists).toBe(false);
    await expect(getAuth(adminApp()).getUser(uid)).rejects.toMatchObject({ code: 'auth/user-not-found' });
  }, 120_000);

  it('accepts a phone-provider ID token too (the alternative sign-in) and records the phone', async () => {
    const idToken = await signInWithPhone('+351912345678');

    const created = await callOk<{ uid: string }>('ensureAccount', { countryCode: 'PT', locale: 'pt-PT' }, { idToken });
    expect((await db.collection(C.accounts).doc(created.uid).get()).data()?.phone).toBe('+351912345678');
  }, 60_000);
});

describe('the triggers run in the emulator', () => {
  it('sends the professional a generic push for a new booking and a silent push for a sealed form', async () => {
    const { instant } = nextTuesday10();
    const start = instant.replace('13:00', '19:00'); // 16:00 in Sao Paulo
    const booked = await callOk<{ manageToken: string; bookingId: string }>('createBooking', {
      slug, serviceId: SERVICE.deepCleansing, startsAt: start,
      client: { name: 'Carla Dias', phone: '+5511933334444', locale: 'pt-BR' },
      verification: { method: 'phone', idToken: await signInWithPhone('+5511933334444') }, idempotencyKey: randomUUID()
    });

    const push = await waitUntil(async () => {
      const found = await db.collection(C.emulatorOutbox).where('type', '==', 'push').where('kind', '==', 'booking').where('id', '==', booked.bookingId).get();
      return found.empty ? undefined : found.docs[0]?.data();
    });
    expect(push).toMatchObject({ kind: 'booking', id: booked.bookingId, devices: 1 });
    expect(JSON.stringify(push)).not.toMatch(/Carla|5511933334444/);

    const itemId = randomUUID();
    await callOk('submitSealed', {
      token: booked.manageToken,
      envelope: { v: 1, suite: 'hpke-x25519-hkdf-sha256-chacha20poly1305', keyId: inboxKey.keyId, kind: 'intake', itemId, enc: base64url(randomBytes(32)), ct: base64url(randomBytes(700)) }
    });
    const silent = await waitUntil(async () => {
      const found = await db.collection(C.emulatorOutbox).where('kind', '==', 'mailbox').where('id', '==', itemId).get();
      return found.empty ? undefined : found.docs[0]?.data();
    });
    expect(silent).toMatchObject({ kind: 'mailbox', id: itemId });

    const item = await callOk<{ envelope: { itemId: string } }>('getMailboxItem', { itemId }, { idToken: ownerToken });
    expect(item.envelope.itemId).toBe(itemId);
    expect(await callOk('acknowledgeMailboxItem', { itemId }, { idToken: ownerToken })).toEqual({ ok: true });
  }, 120_000);
});

describe('plain HTTPS functions', () => {
  it('answers the calendar download with 404 for a bad or unknown link, 405 for POST', async () => {
    expect((await fetch(`${FUNCTIONS_BASE}/getIcs?token=not-a-token`)).status).toBe(404);
    expect((await fetch(`${FUNCTIONS_BASE}/getIcs?token=${'a'.repeat(22)}`)).status).toBe(404);
    expect((await fetch(`${FUNCTIONS_BASE}/getIcs`)).status).toBe(404);
    expect((await fetch(`${FUNCTIONS_BASE}/getIcs?token=${'a'.repeat(22)}`, { method: 'POST' })).status).toBe(405);
  });

  it('answers Apple\'s webhook with 503 while the verifier is not configured, and 405 for GET', async () => {
    const post = await fetch(`${FUNCTIONS_BASE}/appStoreNotifications`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ signedPayload: 'x'.repeat(40) })
    });
    expect(post.status).toBe(503);
    expect((await fetch(`${FUNCTIONS_BASE}/appStoreNotifications`)).status).toBe(405);
    expect((await fetch(`${FUNCTIONS_BASE}/appStoreNotifications`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })).status).toBe(400);
  });
});

describe('browser access (CORS)', () => {
  it('answers a preflight from the web app\'s origin', async () => {
    const response = await fetch(`${FUNCTIONS_BASE}/getPublicPage`, {
      method: 'OPTIONS',
      headers: { Origin: ORIGIN, 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'content-type,x-firebase-appcheck,authorization' }
    });

    expect(response.status).toBeLessThan(300);
    expect(response.headers.get('access-control-allow-origin')).toBeTruthy();
    expect((response.headers.get('access-control-allow-headers') ?? '').toLowerCase()).toContain('x-firebase-appcheck');
  });

  it('keeps the compiled function list equal to the registry', () => {
    const built = readFileSync(fileURLToPath(new URL('../../lib/index.js', import.meta.url)), 'utf8');
    for (const useCase of USE_CASES) expect(built).toContain(`export const ${useCase.name} =`);
  });
});
