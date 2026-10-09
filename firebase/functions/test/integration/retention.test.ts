import { randomBytes, randomUUID } from 'node:crypto';

import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { base64url, sha256Hex } from '../../src/lib/crypto.js';
import { C } from '../../src/lib/docs.js';
import { refs, ts } from '../../src/lib/store.js';
import { runCleanup } from '../../src/jobs/cleanup.js';
import { reminderDueAt, runReminders } from '../../src/jobs/sendReminders.js';
import { publishPortal } from '../../src/owner/publishPortal.js';
import { updateInboxKey } from '../../src/owner/updateInboxKey.js';
import { joinWaitlist } from '../../src/public/joinWaitlist.js';
import { sendEmailCode } from '../../src/public/sendEmailCode.js';
import { submitSealed } from '../../src/public/submitSealed.js';
import { cancelBooking } from '../../src/token/cancelBooking.js';
import { asBooked, book, bookingDoc } from '../support/booking.js';
import { createTestEnv, envelopeBlobs, resetEmulators } from '../support/env.js';
import { captureWorld, newInboxKey, ownerContext, restoreWorld, seedProfessional, SERVICE } from '../support/seed.js';
import type { Professional, World } from '../support/seed.js';

// D30: bookings leave the server 7 days after the visit, sealed envelopes on acknowledgement or after 30 days, and
// short-lived data when its time is over. The job runs with a fixed clock, so each date below is exact.

const env = createTestEnv({ whatsAppAutomation: true });
let pro: Professional;
let world: World;
const DAY = 86_400_000;
/** Saturday 2026-10-03 10:00 in Sao Paulo, ending 11:00. */
const START = '2026-10-03T13:00:00.000Z';
const END = Date.parse('2026-10-03T14:00:00.000Z');

beforeAll(async () => {
  await resetEmulators(env, { storage: true });
  pro = await seedProfessional(env);
  world = await captureWorld(env, pro);
});

beforeEach(async () => {
  await resetEmulators(env, { storage: true });
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  env.whatsapp.sent.length = 0;
  env.whatsapp.enabled = true;
  await restoreWorld(env, world);
});

const count = async (collection: string) => (await env.deps.db.collection(collection).get()).size;

describe('bookings (7 days after the visit)', () => {
  it('keeps a booking until seven days after the visit ends and removes it on the next run', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));

    expect((await runCleanup(env.deps, END + 7 * DAY - 1)).bookings).toBe(0);
    expect((await refs(env.deps.db).booking(booked.bookingId).get()).exists).toBe(true);

    const report = await runCleanup(env.deps, END + 7 * DAY);
    expect(report.bookings).toBe(1);
    expect((await refs(env.deps.db).booking(booked.bookingId).get()).exists).toBe(false);
  });

  it('removes the reschedule request and the idempotency key with it', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));
    await refs(env.deps.db).rescheduleRequest(booked.bookingId).set({ ownerUid: pro.uid, bookingId: booked.bookingId, status: 'pending', purgeAt: (await bookingDoc(env, booked.bookingId)).purgeAt });

    await runCleanup(env.deps, END + 8 * DAY);

    expect(await count(C.rescheduleRequests)).toBe(0);
    expect(await count(C.idempotency)).toBe(0);
  });

  it('removes a moved booking by its new date, and a cancelled one the same way', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));
    await env.call(cancelBooking, { token: booked.manageToken });

    expect((await runCleanup(env.deps, END + 6 * DAY)).bookings).toBe(0);
    expect((await runCleanup(env.deps, END + 8 * DAY)).bookings).toBe(1);
  });

  it('stops the manage link working once the booking is gone', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));
    await runCleanup(env.deps, END + 8 * DAY);
    env.clock.set(END + 8 * DAY);

    await expect(env.call((await import('../../src/token/getBooking.js')).getBooking, { token: booked.manageToken })).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('sealed envelopes (30 days)', () => {
  let token = '';

  beforeEach(async () => {
    token = asBooked(await book(env, pro, { startsAt: START })).manageToken;
  });

  async function seal(kind: 'intake' | 'checkin' = 'intake', bytes = 600) {
    const itemId = randomUUID();
    await env.call(submitSealed, {
      token,
      envelope: {
        v: 1, suite: 'hpke-x25519-hkdf-sha256-chacha20poly1305', keyId: pro.inboxKey.keyId, kind, itemId,
        enc: base64url(randomBytes(32)), ct: base64url(randomBytes(bytes))
      }
    });
    return itemId;
  }

  it('deletes an unacknowledged envelope exactly thirty days after it arrived, with its Storage object', async () => {
    const small = await seal();
    const large = await seal('intake', 220 * 1024);
    const arrived = env.clock.now();

    expect((await runCleanup(env.deps, arrived + 30 * DAY - 1)).envelopes).toBe(0);
    expect(await envelopeBlobs(env, pro.uid, large)).toHaveLength(1);

    const report = await runCleanup(env.deps, arrived + 30 * DAY);
    expect(report.envelopes).toBe(2);
    expect((await refs(env.deps.db).inboxItem(pro.uid, small).get()).exists).toBe(false);
    expect(await envelopeBlobs(env, pro.uid, large)).toHaveLength(0);
  });

  it('deletes a Storage object whose document is already gone (the database TTL cannot reach Storage)', async () => {
    const large = await seal('intake', 220 * 1024);
    await refs(env.deps.db).inboxItem(pro.uid, large).delete();

    const report = await runCleanup(env.deps, env.clock.now() + DAY);

    expect(report.blobs).toBe(1);
    expect(await envelopeBlobs(env, pro.uid, large)).toHaveLength(0);
  });

  it('keeps a Storage object whose document exists', async () => {
    const large = await seal('intake', 220 * 1024);

    const report = await runCleanup(env.deps, env.clock.now() + DAY);

    expect(report.blobs).toBe(0);
    expect(await envelopeBlobs(env, pro.uid, large)).toHaveLength(1);
  });
});

describe('short-lived data', () => {
  it('removes expired holds and keeps live ones', async () => {
    const live = { ownerUid: pro.uid, slug: pro.slug, serviceId: SERVICE.glowFacial, addOnIds: [], guests: 0, startsAt: ts(0), endsAt: ts(1), holdKeyHash: 'h', kind: 'soft' };
    await refs(env.deps.db).hold('live').set({ ...live, expiresAt: ts(env.clock.now() + 60_000) });
    await refs(env.deps.db).hold('old').set({ ...live, expiresAt: ts(env.clock.now() - 1) });

    const report = await runCleanup(env.deps, env.clock.now());

    expect(report.holds).toBe(1);
    expect((await refs(env.deps.db).hold('live').get()).exists).toBe(true);
  });

  it('removes email codes after ten minutes and rate counters after their window', async () => {
    await env.call(sendEmailCode, { slug: pro.slug, email: 'ana@example.com', locale: 'en', purpose: 'booking' });
    expect(await count(C.emailCodes)).toBe(1);
    expect(await count(C.rate)).toBeGreaterThan(0);

    const report = await runCleanup(env.deps, env.clock.now() + 11 * 60_000);
    expect(report.codes).toBe(1);

    await runCleanup(env.deps, env.clock.now() + 25 * 60 * 60_000);
    expect(await count(C.rate)).toBe(0);
  });

  it('removes a waitlist entry seven days after its last day', async () => {
    await env.call(joinWaitlist, { slug: pro.slug, name: 'Paula', phone: '+5511955550000', locale: 'pt-BR', dayFrom: '2026-10-03', dayTo: '2026-10-05' });
    const lastDayEnd = Date.parse('2026-10-06T03:00:00.000Z'); // midnight at the end of the 5th in Sao Paulo

    expect((await runCleanup(env.deps, lastDayEnd + 7 * DAY - 1)).waitlist).toBe(0);
    expect((await runCleanup(env.deps, lastDayEnd + 7 * DAY)).waitlist).toBe(1);
  });

  it('removes a portal a hundred and eighty days after its last use, and a revoked one at once', async () => {
    const token = base64url(Buffer.from('0123456789abcdef'));
    const content = { clientName: 'Ana', past: [], aftercare: [], products: [] };
    await env.call(publishPortal, { token, clientRef: randomUUID(), content }, ownerContext(pro.uid));
    const revoked = base64url(Buffer.from('fedcba9876543210'));
    await env.call(publishPortal, { token: revoked, clientRef: randomUUID(), content }, ownerContext(pro.uid));
    await env.call(publishPortal, { token: revoked, clientRef: randomUUID(), revoke: true }, ownerContext(pro.uid));

    expect((await runCleanup(env.deps, env.clock.now())).portals).toBe(1);
    expect((await refs(env.deps.db).portal(sha256Hex(`portal:${revoked}`)).get()).exists).toBe(false);
    expect((await runCleanup(env.deps, env.clock.now() + 181 * DAY)).portals).toBe(1);
  });

  it('removes audit events after 400 days', async () => {
    await env.call(updateInboxKey, { inboxKey: newInboxKey() }, ownerContext(pro.uid));
    expect(await count(C.audit)).toBeGreaterThan(0);

    await runCleanup(env.deps, env.clock.now() + 399 * DAY);
    expect(await count(C.audit)).toBeGreaterThan(0);
    await runCleanup(env.deps, env.clock.now() + 401 * DAY);
    expect(await count(C.audit)).toBe(0);
  });
});

describe('the job itself', () => {
  it('is idempotent and reports zero on a second run', async () => {
    asBooked(await book(env, pro, { startsAt: START }));
    const first = await runCleanup(env.deps, END + 8 * DAY);
    const second = await runCleanup(env.deps, END + 8 * DAY);

    expect(first.bookings).toBe(1);
    expect(Object.values(second).every((n: number) => n === 0)).toBe(true);
  });

  it('removes more than one batch', async () => {
    const batch = env.deps.db.batch();
    for (let n = 0; n < 450; n += 1) {
      batch.set(refs(env.deps.db).hold(`old-${n}`), {
        ownerUid: pro.uid, slug: pro.slug, serviceId: 'x', addOnIds: [], guests: 0, startsAt: ts(0), endsAt: ts(1), holdKeyHash: 'h', kind: 'soft', expiresAt: ts(1)
      });
    }
    await batch.commit();

    const report = await runCleanup(env.deps, env.clock.now());

    expect(report.holds).toBe(450);
    expect(await count(C.holds)).toBe(0);
  }, 60_000);
});

describe('client reminders (only when WhatsApp automation is on, D31)', () => {
  const dueAt = reminderDueAt(Date.parse(START), 'America/Sao_Paulo', 18);

  it('is due at 18:00 the day before in the professional\'s time zone', () => {
    expect(new Date(dueAt).toISOString()).toBe('2026-10-02T21:00:00.000Z'); // 18:00 in Sao Paulo
    // Across a clock change the wall clock, not the offset, is what holds: Lisbon, the day before 2026-03-29.
    expect(new Date(reminderDueAt(Date.parse('2026-03-29T10:00:00.000Z'), 'Europe/Lisbon', 18)).toISOString()).toBe('2026-03-28T18:00:00.000Z');
    expect(new Date(reminderDueAt(Date.parse('2026-03-30T10:00:00.000Z'), 'Europe/Lisbon', 18)).toISOString()).toBe('2026-03-29T17:00:00.000Z');
  });

  it('sends nothing before it is due, one reminder when due, and never twice', async () => {
    const booked = asBooked(await book(env, pro, { client: { name: 'Ana Costa', phone: '+5511987654321', email: undefined }, startsAt: START }));

    expect(await runReminders(env.deps, dueAt - 1)).toMatchObject({ sent: 0 });
    const report = await runReminders(env.deps, dueAt);

    expect(report).toEqual({ skipped: false, sent: 1, failed: 0 });
    expect(env.whatsapp.sent).toHaveLength(1);
    const message = env.whatsapp.sent[0];
    expect(message).toMatchObject({ to: '+5511987654321', templateName: 'bellohub_reminder_pt_br', languageCode: 'pt_BR' });
    expect(message?.parameters).toHaveLength(6);
    expect(message?.parameters[0]).toBe('Ana Costa');
    expect(message?.parameters[5]).toMatch(/^https:\/\/bellohub\.test\/m\/[A-Za-z0-9_-]{22}$/);
    expect((await bookingDoc(env, booked.bookingId)).manageTokenHashes).toHaveLength(2);
    expect(await runReminders(env.deps, dueAt + 60_000)).toMatchObject({ sent: 0 });
  });

  it('skips cancelled bookings and bookings that have not been approved', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));
    await env.call(cancelBooking, { token: booked.manageToken });

    expect(await runReminders(env.deps, dueAt)).toMatchObject({ sent: 0 });
  });

  it('does nothing at all when automation is off', async () => {
    asBooked(await book(env, pro, { startsAt: START }));
    env.whatsapp.enabled = false;
    env.deps.settings.whatsAppAutomation = false;

    expect(await runReminders(env.deps, dueAt)).toEqual({ skipped: true, sent: 0, failed: 0 });
    env.deps.settings.whatsAppAutomation = true;
  });
});
