import { randomBytes, randomUUID } from 'node:crypto';

import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { base64url, sha256Hex } from '../../src/lib/crypto.js';
import type { InboxItemDoc } from '../../src/lib/docs.js';
import { AppError } from '../../src/lib/errors.js';
import { runCleanup } from '../../src/jobs/cleanup.js';
import { refs } from '../../src/lib/store.js';
import { deleteClientServerData } from '../../src/owner/deleteClientServerData.js';
import { publishAvailability } from '../../src/owner/publishAvailability.js';
import { createBooking } from '../../src/public/createBooking.js';
import { findBookings } from '../../src/public/findBookings.js';
import { getSlots } from '../../src/public/getSlots.js';
import { holdSlot } from '../../src/public/holdSlot.js';
import { sendEmailCode } from '../../src/public/sendEmailCode.js';
import { submitSealed } from '../../src/public/submitSealed.js';
import { verifyEmailCode } from '../../src/public/verifyEmailCode.js';
import { reportLate } from '../../src/token/reportLate.js';
import { rescheduleBooking } from '../../src/token/rescheduleBooking.js';
import { ANA, BIA, asBooked, book, bookingDoc } from '../support/booking.js';
import { createTestEnv, envelopeBlobs, resetEmulators } from '../support/env.js';
import { captureWorld, FRIDAY_10, mariaAvailability, ownerContext, restoreWorld, SERVICE, seedProfessional } from '../support/seed.js';
import type { Professional, World } from '../support/seed.js';

// The adversarial review of 2026-10 (docs/agent-notes/backend.md, "Security review 2026-10"). Each test here first
// failed against the code as it was, or documents a residual behaviour the notes point at. The suites next to this one
// stay the specification of the happy paths.

const env = createTestEnv();
let pro: Professional;
let world: World;
const EMAIL = 'ana@example.com';
const FRIDAY_14 = '2026-10-02T17:00:00.000Z';

beforeAll(async () => {
  await resetEmulators(env, { storage: true });
  pro = await seedProfessional(env);
  world = await captureWorld(env, pro);
});

beforeEach(async () => {
  await resetEmulators(env, { storage: true });
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  env.mail.sent.length = 0;
  env.logs.entries.length = 0;
  await restoreWorld(env, world);
});

/** A proof of `email`, obtained the way the browser does it. */
async function proofFor(email: string): Promise<string> {
  await env.call(sendEmailCode, { slug: pro.slug, email, locale: 'pt-BR', purpose: 'booking' });
  const code = /\b(\d{6})\b/.exec(env.mail.sent.at(-1)?.text ?? '')?.[1] ?? '';
  return ((await env.call(verifyEmailCode, { email, code })) as { proof: string }).proof;
}

function envelope(overrides: Record<string, unknown> = {}, ctBytes = 600) {
  return {
    v: 1,
    suite: 'hpke-x25519-hkdf-sha256-chacha20poly1305',
    keyId: pro.inboxKey.keyId,
    kind: 'intake',
    itemId: randomUUID(),
    enc: base64url(randomBytes(32)),
    ct: base64url(randomBytes(ctBytes)),
    ...overrides
  };
}

const submit = (token: string, sealed: Record<string, unknown>, ip = '203.0.113.5') => env.call(submitSealed, { token, envelope: sealed }, { ip });

const codeOf = (caught: unknown): string => (caught as AppError).code;

describe('tokens: an idempotent replay must show the verification the booking was made with', () => {
  it('refuses a replay that carries a made-up email proof, and still serves a retry with the real one', async () => {
    const key = randomUUID();
    const client = { ...ANA, email: EMAIL };
    const proof = await proofFor(EMAIL);
    const first = asBooked(await book(env, pro, { idempotencyKey: key, client, verification: { method: 'email', proof } }));

    const forged = await book(env, pro, { idempotencyKey: key, client, verification: { method: 'email', proof: 'x'.repeat(22) } }).catch((caught: unknown) => caught);

    expect(codeOf(forged)).toBe('VERIFICATION_FAILED');
    expect((await bookingDoc(env, first.bookingId)).manageTokenHashes).toHaveLength(1);

    const retry = asBooked(await book(env, pro, { idempotencyKey: key, client, verification: { method: 'email', proof } }));
    expect(retry.bookingId).toBe(first.bookingId);
    expect((await bookingDoc(env, first.bookingId)).manageTokenHashes).toHaveLength(2);
  });

  it('refuses a replay that carries a proof issued for another address', async () => {
    const key = randomUUID();
    const client = { ...ANA, email: EMAIL };
    asBooked(await book(env, pro, { idempotencyKey: key, client, verification: { method: 'email', proof: await proofFor(EMAIL) } }));
    const otherProof = await proofFor('other@example.com');

    const forged = await book(env, pro, { idempotencyKey: key, client, verification: { method: 'email', proof: otherProof } }).catch((caught: unknown) => caught);

    expect(codeOf(forged)).toBe('VERIFICATION_FAILED');
  });
});

describe('rate limits: a caller without a credential cannot spend someone else allowance', () => {
  it('does not count made-up email proofs against the phone or the professional in createBooking', async () => {
    const client = { ...ANA, email: EMAIL };
    for (let n = 0; n < 6; n += 1) {
      const outcome = await book(env, pro, { client, ip: `198.51.100.${n}`, verification: { method: 'email', proof: 'x'.repeat(22) } }).catch((caught: unknown) => caught);
      expect(codeOf(outcome)).toBe('VERIFICATION_FAILED');
    }

    expect(asBooked(await book(env, pro, { ip: '198.51.100.99' })).status).toBe('confirmed');
  });

  it('does not count made-up email proofs against the address in findBookings', async () => {
    asBooked(await book(env, pro, { client: { ...ANA, email: EMAIL } }));
    for (let n = 0; n < 6; n += 1) {
      const outcome = await env
        .call(findBookings, { slug: pro.slug, email: EMAIL, verification: { method: 'email', proof: 'x'.repeat(22) } }, { ip: `198.51.100.${n}` })
        .catch((caught: unknown) => caught);
      expect(codeOf(outcome)).toBe('VERIFICATION_FAILED');
    }

    const found = (await env.call(findBookings, { slug: pro.slug, email: EMAIL, verification: { method: 'email', proof: await proofFor(EMAIL) } }, { ip: '198.51.100.99' })) as { bookings: unknown[] };
    expect(found.bookings).toHaveLength(1);
  });

  it('still spends the address of the caller on every attempt', async () => {
    for (let n = 0; n < 10; n += 1) {
      await book(env, pro, { client: { ...ANA, email: EMAIL }, ip: '198.51.100.7', verification: { method: 'email', proof: 'x'.repeat(22) } }).catch(() => undefined);
    }

    const outcome = await book(env, pro, { ip: '198.51.100.7' }).catch((caught: unknown) => caught);

    expect(codeOf(outcome)).toBe('RATE_LIMITED');
  });
});

describe('sealed mailbox: races and volume', () => {
  async function bookingToken(): Promise<{ token: string; bookingId: string }> {
    const booked = asBooked(await book(env, pro, { startsAt: FRIDAY_14 }));
    return { token: booked.manageToken, bookingId: booked.bookingId };
  }

  it('keeps the stored envelope when two DIFFERENT ciphertexts race under one item id', async () => {
    const { token } = await bookingToken();
    const itemId = randomUUID();
    const first = envelope({ itemId }, 220 * 1024);
    const second = envelope({ itemId }, 220 * 1024);

    const results = await Promise.all([
      submit(token, first, '203.0.113.1').catch((caught: unknown) => caught),
      submit(token, second, '203.0.113.2').catch((caught: unknown) => caught)
    ]);

    const codes = results.map((result) => (result instanceof AppError ? result.code : 'ok')).sort();
    expect(codes).toEqual(['CONFLICT', 'ok']);
    const item = (await refs(env.deps.db).inboxItem(pro.uid, itemId).get()).data() as InboxItemDoc;
    expect(item.storagePath).toBeDefined();
    const stored = await env.deps.blobs.get(item.storagePath ?? '');
    expect(stored).not.toBeNull();
    const kept = JSON.parse(stored?.toString('utf8') ?? '{}') as { ct: string };
    expect(sha256Hex(kept.ct)).toBe(item.ctHash);
    // The loser left nothing behind.
    expect(await envelopeBlobs(env, pro.uid, itemId)).toHaveLength(1);
  }, 60_000);

  it('removes, in the cleanup job, an object a lost race left behind, and keeps the one the item points at', async () => {
    const { token } = await bookingToken();
    const sealed = envelope({}, 220 * 1024);
    await submit(token, sealed);
    const leftover = `inbox/${pro.uid}/${sealed.itemId}.0000000000000000.json`;
    await env.deps.blobs.put(leftover, Buffer.from('{}', 'utf8'), 'application/json');

    const report = await runCleanup(env.deps, env.clock.now() + 3_600_000);

    expect(report.blobs).toBe(1);
    expect(await env.deps.blobs.get(leftover)).toBeNull();
    expect(await envelopeBlobs(env, pro.uid, sealed.itemId)).toHaveLength(1);
  }, 60_000);

  it('caps the envelopes one booking can leave unacknowledged', async () => {
    const { token } = await bookingToken();
    for (let n = 0; n < 20; n += 1) {
      if (n > 0 && n % 5 === 0) env.clock.advance(3_600_000);
      expect(await submit(token, envelope({ kind: 'datarequest' }, 100))).toEqual({ ok: true });
    }
    env.clock.advance(3_600_000);

    const outcome = await submit(token, envelope({ kind: 'datarequest' }, 100)).catch((caught: unknown) => caught);

    expect(codeOf(outcome)).toBe('RATE_LIMITED');
    expect((await refs(env.deps.db).inboxItems(pro.uid).get()).size).toBe(20);
  }, 60_000);
});

describe('calendar lock: moving a booking races a new booking for the same time', () => {
  // Tuesday is five days away: inside the free window, so the client may move it herself.
  const TUESDAY_10 = '2026-10-06T13:00:00.000Z';
  const TUESDAY_14 = '2026-10-06T17:00:00.000Z';

  it('gives the time to exactly one of them', async () => {
    const ana = asBooked(await book(env, pro, { startsAt: TUESDAY_10 }));

    const [moved, booked] = await Promise.all([
      env.call(rescheduleBooking, { token: ana.manageToken, startsAt: TUESDAY_14 }) as Promise<{ status: string }>,
      book(env, pro, { client: BIA, startsAt: TUESDAY_14, ip: '198.51.100.2' })
    ]);

    const winners = [moved.status === 'moved', booked.status === 'confirmed'].filter(Boolean);
    expect(winners).toHaveLength(1);
    expect([moved.status, booked.status]).toContain('slotTaken');
    const bookings = (await refs(env.deps.db).bookings().where('ownerUid', '==', pro.uid).get()).docs.map(
      (doc) => doc.data() as { startsAt: { toMillis(): number }; status: string }
    );
    const atTwo = bookings.filter((entry) => entry.startsAt.toMillis() === Date.parse(TUESDAY_14) && entry.status === 'confirmed');
    expect(atTwo).toHaveLength(1);
  }, 60_000);
});

describe('D42: what a client delete does to the count', () => {
  it('never lowers the count; the same phone after a delete is a new registration (no tombstone, ASSUMPTION-18)', async () => {
    asBooked(await book(env, pro, { startsAt: FRIDAY_10 }));
    const count = async () => ((await refs(env.deps.db).account(pro.uid).get()).data() as { registrations: { count: number } }).registrations.count;
    expect(await count()).toBe(1);

    await env.call(deleteClientServerData, { phone: ANA.phone }, ownerContext(pro.uid));
    expect(await count()).toBe(1);

    asBooked(await book(env, pro, { startsAt: FRIDAY_14 }));
    expect(await count()).toBe(2);
  });
});

describe('logging: a rejected input whose field NAME is personal data', () => {
  it('reaches neither the logs nor the failure fields', async () => {
    const phoneAsKey = '+5511977770000';
    const input = { slug: pro.slug, [phoneAsKey]: 'allergic to latex' };

    const outcome = await env.call(getSlots, input).catch((caught: unknown) => caught);

    expect(codeOf(outcome)).toBe('INVALID_ARGUMENT');
    expect(JSON.stringify(env.logs.entries)).not.toContain('977770000');
    expect(JSON.stringify(env.logs.entries)).not.toContain('latex');
  });
});

describe('input validation: the edges', () => {
  it('rejects impossible dates, unknown time zones, huge numbers and oversized envelopes before any work', async () => {
    const who = ownerContext(pro.uid);
    await expect(book(env, pro, { startsAt: '2026-02-30T13:00:00.000Z' })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(getSlots, { slug: pro.slug, serviceId: SERVICE.glowFacial, from: '2026-10-01', to: '2026-11-13' })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(getSlots, { slug: pro.slug, serviceId: SERVICE.glowFacial, from: '2026-10-10', to: '2026-10-01' })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(publishAvailability, mariaAvailability({ timeZoneID: 'Mars/Olympus_Mons' }), who)).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(publishAvailability, mariaAvailability({ bufferMinutes: -1 }), who)).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(publishAvailability, mariaAvailability({ minNoticeHours: 1e12 }), who)).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: FRIDAY_10, holdKey: 'k'.repeat(20), guests: -1 })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(reportLate, { token: 'k'.repeat(22), minutes: 1e9 })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(submit('k'.repeat(22), envelope({ ct: 'A'.repeat(4 * 1024 * 1024 + 4100) }))).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(createBooking, { slug: pro.slug, extra: 1 })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT', details: { fields: expect.arrayContaining(['extra']) as string[] } });
  });

  it('cleans invisible and bidi characters out of a name and refuses a name that is only those', async () => {
    const booked = asBooked(await book(env, pro, { client: { ...ANA, name: 'A‮na​ ⁦Costa⁩' } }));

    expect((await bookingDoc(env, booked.bookingId)).client.name).toBe('Ana Costa');
    await expect(book(env, pro, { client: { ...BIA, name: '​‮' } })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });
});
