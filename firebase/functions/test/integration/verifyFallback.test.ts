// "I didn't get the code" (an unverified request confirmed on WhatsApp), trusted devices (returning clients skip the
// code) and the soft hold that covers the e-mail code's life. docs/agent-notes/verify-fallback.md.

import { randomUUID } from 'node:crypto';

import { FieldValue } from 'firebase-admin/firestore';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { runCleanup } from '../../src/jobs/cleanup.js';
import { deleteClientServerData } from '../../src/owner/deleteClientServerData.js';
import { respondBookingRequest } from '../../src/owner/respondBookingRequest.js';
import type { BookingDoc, HoldDoc, TrustedDeviceDoc } from '../../src/lib/docs.js';
import { refs, ts } from '../../src/lib/store.js';
import { deviceTokenHash } from '../../src/lib/trustedDevices.js';
import { forgetDevice } from '../../src/public/forgetDevice.js';
import { getSlots } from '../../src/public/getSlots.js';
import { holdSlot } from '../../src/public/holdSlot.js';
import { sendEmailCode } from '../../src/public/sendEmailCode.js';
import { verifyEmailCode } from '../../src/public/verifyEmailCode.js';
import { asBooked, book, bookingDoc } from '../support/booking.js';
import type { BookOptions } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { captureWorld, FRIDAY_10, ownerContext, restoreWorld, seedProfessional, SERVICE } from '../support/seed.js';
import type { Professional, World } from '../support/seed.js';

const env = createTestEnv();
let pro: Professional;
let world: World;

beforeAll(async () => {
  await resetEmulators(env);
  pro = await seedProfessional(env);
  world = await captureWorld(env, pro);
});

beforeEach(async () => {
  await resetEmulators(env);
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  env.mail.sent.length = 0;
  await restoreWorld(env, world);
});

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const EMAIL = 'ana@example.com';
const ANA = { name: 'Ana Costa', phone: '+5511987654321', email: EMAIL };
/** Saturday 2026-10-03 10:00 in Sao Paulo: more than 24 hours after "now". */
const SATURDAY_10 = '2026-10-03T13:00:00.000Z';

function lastCode(): string {
  const code = /\b(\d{6})\b/.exec(env.mail.sent.at(-1)?.text ?? '')?.[1];
  if (!code) throw new Error('no code in the email');
  return code;
}

/** The page's code path: send, read the e-mail, verify. A new code needs 30 s since the last one. */
async function emailProof(email = EMAIL): Promise<string> {
  env.clock.advance(31_000);
  await env.call(sendEmailCode, { slug: pro.slug, email, locale: 'pt-BR', purpose: 'booking' });
  const result = (await env.call(verifyEmailCode, { email, code: lastCode() })) as { proof: string };
  return result.proof;
}

const whatsapp = (options: BookOptions = {}) => book(env, pro, { client: ANA, verification: { method: 'whatsapp' }, ...options });
const withDevice = (token: string, options: BookOptions = {}) =>
  book(env, pro, { client: ANA, verification: { method: 'device', token }, ...options });

/** A confirmed booking verified by code, which hands out a trusted-device token. */
async function trustedToken(startsAt = FRIDAY_10): Promise<string> {
  const outcome = asBooked(await book(env, pro, { client: ANA, startsAt, verification: { method: 'email', proof: await emailProof() } }));
  expect(outcome.status).toBe('confirmed');
  if (!outcome.deviceToken) throw new Error('no device token');
  return outcome.deviceToken;
}

describe('an unverified request ("I didn\'t get the code" -> WhatsApp)', () => {
  it('is always a request, flagged unverified, with a reference and a 24 hour release, and holds the time', async () => {
    const outcome = asBooked(await whatsapp({ startsAt: SATURDAY_10 }));

    expect(outcome.status).toBe('pendingApproval');
    expect(outcome.reference).toMatch(/^[2-9A-HJKMNP-Z]{5}$/);
    expect(outcome.requestExpiresAt).toBe(new Date(env.clock.now() + DAY).toISOString());
    expect(outcome.emailSent).toBe(false);
    expect(outcome.deviceToken).toBeUndefined();
    const stored = await bookingDoc(env, outcome.bookingId);
    expect(stored.verification).toBe('whatsapp');
    expect(stored.reference).toBe(outcome.reference);
    expect(stored.pendingReason).toBeUndefined();
    expect(stored.client.email).toBe(EMAIL);
    // Nobody else can take the time while she waits for the professional.
    expect((await book(env, pro, { startsAt: SATURDAY_10, client: { name: 'Bia', phone: '+5511976543210' } })).status).toBe('slotTaken');
  });

  it('is released at the visit start when that comes before 24 hours', async () => {
    const outcome = asBooked(await whatsapp({ startsAt: FRIDAY_10 }));

    expect(outcome.requestExpiresAt).toBe(FRIDAY_10);
  });

  it('sends no e-mail when it is made (the address is not proven)', async () => {
    await whatsapp({ startsAt: SATURDAY_10 });

    expect(env.mail.sent).toHaveLength(0);
  });

  it('keeps the reason she would see anyway (her new-client switch) next to the flag', async () => {
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.requiresApproval': true });

    const outcome = asBooked(await whatsapp({ startsAt: SATURDAY_10 }));

    expect((await bookingDoc(env, outcome.bookingId)).pendingReason).toBe('newClient');
  });

  it('is NOT_ALLOWED when her page has no WhatsApp number, and needs the e-mail', async () => {
    await refs(env.deps.db).profile(pro.slug).update({ whatsappE164: FieldValue.delete() });
    await expect(whatsapp({ startsAt: SATURDAY_10 })).rejects.toMatchObject({ code: 'NOT_ALLOWED' });

    await expect(
      book(env, pro, { client: { name: 'Ana', phone: ANA.phone }, verification: { method: 'whatsapp' } })
    ).rejects.toMatchObject({ code: 'INVALID_ARGUMENT', details: { fields: ['client.email'] } });
  });

  it('caps the waiting unverified requests per phone and per e-mail at two', async () => {
    await whatsapp({ startsAt: SATURDAY_10 });
    await whatsapp({ startsAt: '2026-10-03T17:00:00.000Z' });

    const third = await whatsapp({ startsAt: '2026-10-03T19:00:00.000Z' }).catch((error: unknown) => error);
    expect(third).toMatchObject({ code: 'RATE_LIMITED' });
    expect((third as { details: { retryAfterSeconds: number } }).details.retryAfterSeconds).toBe(24 * 3600);
    // Same e-mail, another phone: still capped.
    await expect(
      whatsapp({ startsAt: '2026-10-03T19:00:00.000Z', client: { ...ANA, phone: '+5511911112222' } })
    ).rejects.toMatchObject({ code: 'RATE_LIMITED' });
  });

  it('frees a place under the cap once a request is answered', async () => {
    const first = asBooked(await whatsapp({ startsAt: SATURDAY_10 }));
    await whatsapp({ startsAt: '2026-10-03T17:00:00.000Z' });
    await env.call(respondBookingRequest, { bookingId: first.bookingId, decision: 'decline' }, ownerContext(pro.uid));

    expect((await whatsapp({ startsAt: '2026-10-03T19:00:00.000Z' })).status).toBe('pendingApproval');
  });

  it('limits one caller (IP) to five a day across contacts', async () => {
    const days = ['2026-10-03', '2026-10-04', '2026-10-07', '2026-10-08', '2026-10-09'];
    for (const [index, day] of days.entries()) {
      await whatsapp({ startsAt: `${day}T13:00:00.000Z`, client: { name: 'Ana', phone: `+55119111100${index}0`, email: `a${index}@example.com` } });
    }

    await expect(
      whatsapp({ startsAt: '2026-10-10T13:00:00.000Z', client: { name: 'Ana', phone: '+5511911119999', email: 'z@example.com' } })
    ).rejects.toMatchObject({ code: 'RATE_LIMITED' });
  });

  it('is released by the cleanup job after 24 hours if she does not answer: declined, time free, no e-mail', async () => {
    const outcome = asBooked(await whatsapp({ startsAt: SATURDAY_10 }));

    expect((await runCleanup(env.deps, env.clock.now() + DAY - 1)).expiredRequests).toBe(0);
    const report = await runCleanup(env.deps, env.clock.now() + DAY);

    expect(report.expiredRequests).toBe(1);
    const stored = await bookingDoc(env, outcome.bookingId);
    expect(stored.status).toBe('declined');
    expect(stored.expiredAt).toBeDefined();
    expect(stored.pendingExpiresAt).toBeUndefined();
    expect(env.mail.sent).toHaveLength(0);
    env.clock.advance(DAY);
    const slots = (await env.call(getSlots, { slug: pro.slug, serviceId: SERVICE.glowFacial, from: '2026-10-03', to: '2026-10-03' })) as {
      days: { slots: string[]; more?: string[] }[];
    };
    expect(slots.days.flatMap((day) => [...day.slots, ...(day.more ?? [])])).toContain(SATURDAY_10);
  });

  it('is not released once she approved it, and approving e-mails her personal link with a new manage token', async () => {
    const outcome = asBooked(await whatsapp({ startsAt: SATURDAY_10 }));
    const answer = await env.call(respondBookingRequest, { bookingId: outcome.bookingId, decision: 'approve' }, ownerContext(pro.uid));

    expect(answer).toEqual({ status: 'confirmed' });
    const stored = await bookingDoc(env, outcome.bookingId);
    expect(stored.pendingExpiresAt).toBeUndefined();
    expect(stored.manageTokenHashes).toHaveLength(2);
    expect(env.mail.sent.at(-1)?.to).toBe(EMAIL);
    expect(env.mail.sent.at(-1)?.text).toMatch(/https:\/\/bellohub\.test\/m\/[A-Za-z0-9_-]{22}/);
    expect((await runCleanup(env.deps, env.clock.now() + 2 * DAY)).expiredRequests).toBe(0);
    expect((await bookingDoc(env, outcome.bookingId)).status).toBe('confirmed');
  });

  it('a replay with the same key gives the same request, and cannot be turned into a verified one', async () => {
    const key = randomUUID();
    const first = asBooked(await whatsapp({ startsAt: SATURDAY_10, idempotencyKey: key }));
    const again = asBooked(await whatsapp({ startsAt: SATURDAY_10, idempotencyKey: key }));

    expect(again.bookingId).toBe(first.bookingId);
    expect(again.reference).toBe(first.reference);
    const proof = await emailProof();
    await expect(
      book(env, pro, { client: ANA, startsAt: SATURDAY_10, idempotencyKey: key, verification: { method: 'email', proof } })
    ).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
  });
});

describe('a trusted device (returning clients skip the code)', () => {
  it('is issued once, hashed, for 90 days, only for a confirmed code-verified booking', async () => {
    const token = await trustedToken();

    const stored = (await refs(env.deps.db).trustedDevice(deviceTokenHash(token)).get()).data() as TrustedDeviceDoc;
    expect(stored.slug).toBe(pro.slug);
    expect(stored.ownerUid).toBe(pro.uid);
    expect(stored.expiresAt.toMillis() - stored.createdAt.toMillis()).toBe(90 * DAY);
    expect(JSON.stringify(stored)).not.toContain(token);
    expect(JSON.stringify(stored)).not.toContain(EMAIL);
  });

  it('is not issued for a request that waits for her, nor for a phone booking', async () => {
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.requiresApproval': true });
    const pending = asBooked(await book(env, pro, { client: ANA, startsAt: SATURDAY_10, verification: { method: 'email', proof: await emailProof() } }));
    expect(pending.status).toBe('pendingApproval');
    expect(pending.deviceToken).toBeUndefined();

    await refs(env.deps.db).profile(pro.slug).update({ 'booking.requiresApproval': false });
    expect(asBooked(await book(env, pro, { client: { ...ANA, email: undefined } })).deviceToken).toBeUndefined();
  });

  it('stands in for the code on the same page with the same e-mail, and the booking is confirmed', async () => {
    const token = await trustedToken();

    const second = asBooked(await withDevice(token, { startsAt: SATURDAY_10 }));

    expect(second.status).toBe('confirmed');
    expect(second.deviceToken).toBeUndefined();
    const stored = (await refs(env.deps.db).trustedDevice(deviceTokenHash(token)).get()).data() as TrustedDeviceDoc;
    expect(stored.lastUsedAt).toBeDefined();
  });

  it('is refused for another e-mail, another page, a made-up token and after 90 days', async () => {
    const token = await trustedToken();

    await expect(withDevice(token, { startsAt: SATURDAY_10, client: { ...ANA, email: 'other@example.com' } })).rejects.toMatchObject({
      code: 'VERIFICATION_FAILED'
    });
    const other = await seedProfessional(env, { uid: 'pro-bruna', slug: 'bruna' });
    await expect(
      book(env, other, { client: ANA, startsAt: SATURDAY_10, verification: { method: 'device', token } })
    ).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
    await expect(withDevice('A'.repeat(22), { startsAt: SATURDAY_10 })).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });

    env.clock.advance(90 * DAY);
    await expect(withDevice(token, { startsAt: '2026-12-31T13:00:00.000Z' })).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
  });

  it('asks for the code (VERIFICATION_REQUIRED) when the booking would need her approval', async () => {
    const token = await trustedToken();
    // Her free registrations are used and the client is new to her again (she deleted the contact row).
    const booking = (await refs(env.deps.db).bookings().where('ownerUid', '==', pro.uid).get()).docs[0]?.data() as BookingDoc;
    await refs(env.deps.db).contact(pro.uid, booking.phoneHash).delete();
    await refs(env.deps.db).account(pro.uid).update({ 'registrations.count': 10 });

    await expect(withDevice(token, { startsAt: SATURDAY_10 })).rejects.toMatchObject({ code: 'VERIFICATION_REQUIRED' });
    // Nothing was written.
    expect((await refs(env.deps.db).bookings().where('ownerUid', '==', pro.uid).get()).size).toBe(1);
  });

  it('asks for the code when the client is at the no-show limit, and a pause still answers paused', async () => {
    const token = await trustedToken();
    const booking = (await refs(env.deps.db).bookings().where('ownerUid', '==', pro.uid).get()).docs[0]?.data() as BookingDoc;
    const marks = [1, 2, 3].map((n) => ({ id: `m${n}`, at: ts(Date.parse('2026-09-01T12:00:00.000Z') + n), kind: 'noShow' as const }));
    await refs(env.deps.db).contact(pro.uid, booking.phoneHash).update({ marks });

    await expect(withDevice(token, { startsAt: SATURDAY_10 })).rejects.toMatchObject({ code: 'VERIFICATION_REQUIRED' });
    await refs(env.deps.db).availability(pro.uid).update({ 'noShow.action': 'tell' });
    await expect(withDevice(token, { startsAt: SATURDAY_10 })).rejects.toMatchObject({ code: 'VERIFICATION_REQUIRED' });
    await refs(env.deps.db).availability(pro.uid).update({ 'noShow.action': 'pauseOnline' });
    expect((await withDevice(token, { startsAt: SATURDAY_10 })).status).toBe('paused');
  });

  it('keeps at most five per e-mail and page: a sixth replaces the oldest', async () => {
    const tokens: string[] = [];
    const starts = ['2026-10-02T12:00:00.000Z', '2026-10-02T14:00:00.000Z', '2026-10-02T17:00:00.000Z', '2026-10-02T19:00:00.000Z', '2026-10-02T21:00:00.000Z', SATURDAY_10];
    for (const startsAt of starts) {
      tokens.push(await trustedToken(startsAt));
      // One phone may book five times an hour and ask for five codes an hour.
      env.clock.advance(HOUR);
    }

    expect((await refs(env.deps.db).trustedDevices().get()).size).toBe(5);
    expect((await refs(env.deps.db).trustedDevice(deviceTokenHash(tokens[0] ?? '')).get()).exists).toBe(false);
    expect((await refs(env.deps.db).trustedDevice(deviceTokenHash(tokens[5] ?? '')).get()).exists).toBe(true);
  });

  it('is revoked by "Forget this device", and the answer is the same for an unknown token', async () => {
    const token = await trustedToken();

    expect(await env.call(forgetDevice, { token })).toEqual({ ok: true });
    expect(await env.call(forgetDevice, { token })).toEqual({ ok: true });
    await expect(withDevice(token, { startsAt: SATURDAY_10 })).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
  });

  it('is removed with her data, and by the cleanup job once expired', async () => {
    const token = await trustedToken();
    await env.call(deleteClientServerData, { phone: ANA.phone }, ownerContext(pro.uid));
    expect((await refs(env.deps.db).trustedDevice(deviceTokenHash(token)).get()).exists).toBe(false);

    const second = await trustedToken(SATURDAY_10);
    await runCleanup(env.deps, env.clock.now() + 90 * DAY);
    expect((await refs(env.deps.db).trustedDevice(deviceTokenHash(second)).get()).exists).toBe(false);
  });
});

describe('the soft hold covers the e-mail code', () => {
  const holdKey = 'hold-key-for-ana-0123456789';
  const holdExpiry = async (): Promise<number> => {
    const holds = await refs(env.deps.db).holds().get();
    return (holds.docs[0]?.data() as HoldDoc).expiresAt.toMillis();
  };

  it('extends a live soft hold to the code life when a booking code is sent', async () => {
    await env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: FRIDAY_10, holdKey });
    env.clock.advance(4 * 60_000);

    await env.call(sendEmailCode, { slug: pro.slug, email: EMAIL, locale: 'pt-BR', purpose: 'booking', holdKey });

    expect(await holdExpiry()).toBe(env.clock.now() + 10 * 60_000);
  });

  it('never revives an expired hold and ignores a find code', async () => {
    await env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: FRIDAY_10, holdKey });
    const original = await holdExpiry();
    await env.call(sendEmailCode, { slug: pro.slug, email: EMAIL, locale: 'pt-BR', purpose: 'find', holdKey });
    expect(await holdExpiry()).toBe(original);

    env.clock.advance(6 * 60_000);
    await env.call(sendEmailCode, { slug: pro.slug, email: EMAIL, locale: 'pt-BR', purpose: 'booking', holdKey });
    expect(await holdExpiry()).toBe(original);
  });
});
