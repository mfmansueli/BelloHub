import { randomBytes, randomUUID } from 'node:crypto';

import { beforeAll, describe, expect, it } from 'vitest';

import { base64url } from '../../src/lib/crypto.js';
import { refs } from '../../src/lib/store.js';
import { acknowledgeMailboxItem } from '../../src/owner/acknowledgeMailboxItem.js';
import { deleteAccount } from '../../src/owner/deleteAccount.js';
import { publishPortal } from '../../src/owner/publishPortal.js';
import { registerDevice } from '../../src/owner/registerDevice.js';
import { reserveRegistration } from '../../src/owner/reserveRegistration.js';
import { createBooking } from '../../src/public/createBooking.js';
import { findBookings } from '../../src/public/findBookings.js';
import { getPortal } from '../../src/public/getPortal.js';
import { joinWaitlist } from '../../src/public/joinWaitlist.js';
import { sendEmailCode } from '../../src/public/sendEmailCode.js';
import { submitSealed } from '../../src/public/submitSealed.js';
import { verifyEmailCode } from '../../src/public/verifyEmailCode.js';
import { cancelBooking } from '../../src/token/cancelBooking.js';
import { getBooking } from '../../src/token/getBooking.js';
import { rebook } from '../../src/token/rebook.js';
import { handleBookingWritten } from '../../src/triggers/handleBookingWritten.js';
import { asBooked, book } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { ownerContext, seedProfessional } from '../support/seed.js';

// docs/06 section 8 and docs/11 section 9: logs hold ids, kinds, sizes, durations and counts and nothing else. This runs
// a whole day of the product with real-looking personal data and then searches EVERYTHING the server logged for it.

const env = createTestEnv();
const SECRET_NAME = 'Zuleika Quasimodo-Brandao';
const SECRET_PHONE = '+5511987650099';
const SECRET_EMAIL = 'zuleika.secret@example.com';
const SECRET_NOTE = 'allergic to latex and pregnant';
const START = '2026-10-03T13:00:00.000Z';

describe('logs contain no personal data', () => {
  const secrets: string[] = [SECRET_NAME, 'Quasimodo', SECRET_PHONE, SECRET_PHONE.slice(3), SECRET_EMAIL, 'zuleika', SECRET_NOTE, 'latex'];

  beforeAll(async () => {
    await resetEmulators(env, { storage: true });
    const pro = await seedProfessional(env);
    const owner = ownerContext(pro.uid);
    const client = { name: SECRET_NAME, phone: SECRET_PHONE, email: SECRET_EMAIL };
    env.logs.entries.length = 0;

    // Email verification, a booking with a note, the management page, a late cancellation, finding it again.
    await env.call(sendEmailCode, { slug: pro.slug, email: SECRET_EMAIL, locale: 'pt-BR', purpose: 'booking' });
    const code = /\b(\d{6})\b/.exec(env.mail.sent.at(-1)?.text ?? '')?.[1] ?? '';
    secrets.push(code);
    const proof = ((await env.call(verifyEmailCode, { email: SECRET_EMAIL, code })) as { proof: string }).proof;
    secrets.push(proof);
    const booked = asBooked(await book(env, pro, { client, startsAt: START, note: SECRET_NOTE, verification: { method: 'email', proof } }));
    secrets.push(booked.manageToken);
    await env.call(getBooking, { token: booked.manageToken });
    const idToken = env.phoneToken(SECRET_PHONE);
    secrets.push(idToken);
    const found = (await env.call(findBookings, { slug: pro.slug, phone: SECRET_PHONE, verification: { method: 'phone', idToken } })) as { bookings: { manageToken: string }[] };
    secrets.push(...found.bookings.map((entry) => entry.manageToken));
    await env.call(rebook, { token: booked.manageToken, startsAt: '2026-10-03T17:00:00.000Z', idempotencyKey: randomUUID() });
    await env.call(cancelBooking, { token: booked.manageToken, reason: SECRET_NOTE });

    // A sealed form of a visit and its acknowledgement; a device; the registration counter; a waitlist entry; the portal.
    const sealedCt = base64url(randomBytes(900));
    const sealedEnc = base64url(randomBytes(32));
    secrets.push(sealedCt, sealedEnc);
    const second = asBooked(await book(env, pro, { client, startsAt: '2026-10-03T19:00:00.000Z' }));
    secrets.push(second.manageToken);
    const itemId = randomUUID();
    await env.call(submitSealed, {
      token: second.manageToken,
      envelope: { v: 1, suite: 'hpke-x25519-hkdf-sha256-chacha20poly1305', keyId: pro.inboxKey.keyId, kind: 'intake', itemId, enc: sealedEnc, ct: sealedCt }
    });
    await env.call(acknowledgeMailboxItem, { itemId }, owner);
    const fcm = `fcm-token-secret-${'z'.repeat(40)}`;
    secrets.push(fcm);
    await env.call(registerDevice, { fcmToken: fcm, platform: 'ios' }, owner);
    await env.call(reserveRegistration, { clientId: randomUUID(), phone: SECRET_PHONE }, owner);
    await env.call(joinWaitlist, { slug: pro.slug, name: SECRET_NAME, phone: '+5511955551234', locale: 'pt-BR', dayFrom: '2026-10-03', dayTo: '2026-10-04' });
    const portalToken = base64url(Buffer.from('0123456789abcdef'));
    secrets.push(portalToken);
    await env.call(publishPortal, { token: portalToken, clientRef: randomUUID(), content: { clientName: SECRET_NAME, past: [], aftercare: [{ title: 'Aftercare', lines: [SECRET_NOTE] }], products: [] } }, owner);
    await env.call(getPortal, { token: portalToken });

    // Triggers, and requests that fail in every way a request can fail, carrying personal data in the input.
    const stored = (await refs(env.deps.db).booking(second.bookingId).get()).data();
    if (stored) await handleBookingWritten(env.deps, second.bookingId, undefined, stored as never);
    for (const bad of [
      { slug: pro.slug, client: { name: SECRET_NAME, phone: 'not-a-phone', locale: 'pt-BR', diagnosis: SECRET_NOTE } },
      { slug: 'nobody', serviceId: randomUUID(), startsAt: START, client: { name: SECRET_NAME, phone: SECRET_PHONE, locale: 'pt-BR' }, verification: { method: 'phone', idToken: 'x'.repeat(30) }, idempotencyKey: randomUUID() }
    ]) {
      await env.call(createBooking, bad).catch(() => undefined);
    }
    await env.call(getBooking, { token: 'k'.repeat(22) }).catch(() => undefined);
    await env.call(deleteAccount, { confirm: true }, owner);
  }, 120_000);

  it('wrote something, so the search below is not vacuous', () => {
    expect(env.logs.entries.length).toBeGreaterThan(20);
    expect(env.logs.entries.some((entry) => entry.event === 'booking.created')).toBe(true);
    expect(env.logs.entries.some((entry) => entry.event === 'sealed.stored')).toBe(true);
    expect(env.logs.entries.some((entry) => entry.event === 'account.deleted')).toBe(true);
  });

  it('never wrote a name, phone, email, note, token, code, proof, envelope or push token', () => {
    const everything = JSON.stringify(env.logs.entries);
    for (const secret of secrets) {
      expect(everything, `a log line contains ${secret.slice(0, 6)}...`).not.toContain(secret);
    }
  });

  it('only ever used the closed list of field names, with id-shaped or label-shaped values', () => {
    for (const entry of env.logs.entries) {
      expect(entry.event).toMatch(/^[A-Za-z0-9_.:-]{1,60}$/);
      for (const [key, value] of Object.entries(entry.fields)) {
        expect(['uid', 'ownerUid', 'bookingId', 'itemId', 'requestId', 'waitlistId', 'holdId', 'accountId', 'scope', 'kind', 'status', 'decision', 'code', 'function', 'reason', 'phase', 'job', 'platform', 'suite', 'provider', 'template', 'count', 'sizeBytes', 'durationMs', 'attempt', 'deleted', 'expired', 'bookings', 'holds', 'envelopes', 'codes', 'portals', 'waitlist', 'requests', 'rows', 'sent', 'failed', 'registrations', 'httpStatus', 'ok', 'dropped']).toContain(key);
        if (typeof value === 'string') expect(value).toMatch(/^[A-Za-z0-9_.:-]{1,64}$|^\[redacted\]$|^unknown-field$/);
      }
    }
  });

  it('logs failures by code and function only', () => {
    const failures = env.logs.entries.filter((entry) => entry.event === 'call.rejected' || entry.event === 'call.failed');
    expect(failures.length).toBeGreaterThan(0);
    for (const failure of failures) expect(Object.keys(failure.fields).sort()).toSatisfy((keys: string[]) => keys.every((key) => ['code', 'durationMs', 'function', 'reason'].includes(key)));
  });
});
