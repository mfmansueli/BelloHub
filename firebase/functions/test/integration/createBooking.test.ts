import { randomUUID } from 'node:crypto';

import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { AppError } from '../../src/lib/errors.js';
import { ts, refs } from '../../src/lib/store.js';
import { holdSlot } from '../../src/public/holdSlot.js';
import { ANA, BIA, asBooked, book, bookingDoc } from '../support/booking.js';
import type { Outcome } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { ADDON, FRIDAY_10, SERVICE, seedProfessional, captureWorld, restoreWorld } from '../support/seed.js';
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

async function setRegistrations(count: number, plan?: { state: 'active'; expiresAt: number }): Promise<void> {
  await refs(env.deps.db)
    .account(pro.uid)
    .update({
      'registrations.count': count,
      ...(plan ? { plan: { state: plan.state, expiresAt: ts(plan.expiresAt), source: 'appStore' } } : {})
    });
}

async function registrations(): Promise<number> {
  return ((await refs(env.deps.db).account(pro.uid).get()).data() as { registrations: { count: number } }).registrations.count;
}

describe('createBooking: the booking itself (D32)', () => {
  it('confirms a booking for a verified phone and stores only the hash of the manage token', async () => {
    const outcome = asBooked(await book(env, pro, { note: 'First time here' }));

    expect(outcome.status).toBe('confirmed');
    expect(outcome.startsAt).toBe('2026-10-02T13:00:00.000Z');
    expect(outcome.endsAt).toBe('2026-10-02T14:00:00.000Z');
    expect(outcome.timeZoneID).toBe('America/Sao_Paulo');
    expect(outcome.serviceName).toBe('Glow Facial');
    expect(outcome.manageToken).toMatch(/^[A-Za-z0-9_-]{22}$/);

    const stored = await bookingDoc(env, outcome.bookingId);
    expect(stored.status).toBe('confirmed');
    expect(stored.ownerUid).toBe(pro.uid);
    expect(stored.durationMinutes).toBe(60);
    expect(stored.manageTokenHashes).toHaveLength(1);
    expect(JSON.stringify(stored)).not.toContain(outcome.manageToken);
    expect(stored.policy.freeWindowHours).toBe(24);
    expect(stored.purgeAt.toMillis()).toBe(Date.parse('2026-10-09T14:00:00.000Z'));
    expect(stored.note).toBe('First time here');
    expect(stored.client.phone).toBe(ANA.phone);
  });

  it('adds add-ons and guests back to back to the time it occupies (D19)', async () => {
    const outcome = asBooked(await book(env, pro, { addOnIds: [ADDON.mask], guests: 1 }));

    // 60 (service) + 15 (mask) + 60 (one guest, same service) = 135 minutes
    expect(outcome.endsAt).toBe('2026-10-02T15:15:00.000Z');
    expect((await bookingDoc(env, outcome.bookingId)).durationMinutes).toBe(135);
  });

  it('refuses a phone that is not the verified one', async () => {
    const token = env.phoneToken(BIA.phone);

    await expect(book(env, pro, { verification: { method: 'phone', idToken: token } })).rejects.toMatchObject({
      code: 'VERIFICATION_FAILED'
    });
  });

  it('refuses a phone sign-in older than ten minutes', async () => {
    const token = env.phoneToken(ANA.phone);
    env.clock.advance(11 * 60_000);

    await expect(book(env, pro, { verification: { method: 'phone', idToken: token } })).rejects.toMatchObject({
      code: 'VERIFICATION_FAILED'
    });
  });

  it('emails the confirmation with the personal link when an email was given', async () => {
    const outcome = asBooked(await book(env, pro, { client: { ...ANA, email: 'ana@example.com' } }));

    expect(outcome.emailSent).toBe(true);
    expect(env.mail.sent).toHaveLength(1);
    expect(env.mail.sent[0]?.to).toBe('ana@example.com');
    expect(env.mail.sent[0]?.text).toContain(`https://bellohub.test/m/${outcome.manageToken}`);
    expect(env.mail.sent[0]?.text).toContain('Glow Facial');
  });

  it('still books when the email provider is down', async () => {
    env.mail.failNext = true;
    const outcome = asBooked(await book(env, pro, { client: { ...ANA, email: 'ana@example.com' } }));

    expect(outcome.status).toBe('confirmed');
    expect(outcome.emailSent).toBe(false);
  });

  it('rejects an unknown service, an unknown page and a time that is not an offered start', async () => {
    await expect(book(env, pro, { serviceId: randomUUID() })).rejects.toMatchObject({ code: 'NOT_FOUND' });
    await expect(book(env, pro, { slug: 'nobody-here' })).rejects.toMatchObject({ code: 'NOT_FOUND' });
    const offGrid = await book(env, pro, { startsAt: '2026-10-02T13:07:00.000Z' });
    expect(offGrid.status).toBe('slotTaken');
  });

  it('rejects more guests than she allows', async () => {
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.maxGuests': 0 });

    await expect(book(env, pro, { guests: 1 })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });
});

describe('createBooking: double booking (D32)', () => {
  it('lets exactly one of two simultaneous requests for the same slot win', async () => {
    const results = await Promise.all([
      book(env, pro, { client: ANA, ip: '203.0.113.1' }),
      book(env, pro, { client: BIA, ip: '203.0.113.2' })
    ]);

    expect(results.filter((result) => result.status === 'confirmed')).toHaveLength(1);
    const loser = results.find((result) => result.status === 'slotTaken');
    expect(loser).toBeDefined();
    if (loser?.status === 'slotTaken') expect(loser.alternatives.length).toBeGreaterThan(0);

    const bookings = await refs(env.deps.db).bookings().get();
    expect(bookings.size).toBe(1);
  });

  it('lets exactly one of ten simultaneous requests win, however many callers race', async () => {
    const callers = Array.from({ length: 10 }, (_, index) => ({
      name: `Client ${index}`,
      phone: `+55119000000${String(index).padStart(2, '0')}`,
      email: undefined
    }));

    const results = await Promise.all(callers.map((client, index) => book(env, pro, { client, ip: `198.51.100.${index}` })));

    expect(results.filter((result) => result.status === 'confirmed')).toHaveLength(1);
    expect(results.filter((result) => result.status === 'slotTaken')).toHaveLength(9);
    expect((await refs(env.deps.db).bookings().get()).size).toBe(1);
  }, 60_000);

  it('books overlapping but different start times only once (the second overlaps the first)', async () => {
    const results = await Promise.all([
      book(env, pro, { client: ANA, startsAt: '2026-10-02T13:00:00.000Z', ip: '203.0.113.1' }),
      book(env, pro, { client: BIA, startsAt: '2026-10-02T13:30:00.000Z', ip: '203.0.113.2' })
    ]);

    expect(results.filter((result) => result.status === 'confirmed')).toHaveLength(1);
  });

  it('lets two different slots be booked at the same time', async () => {
    const results = await Promise.all([
      book(env, pro, { client: ANA, startsAt: '2026-10-02T12:00:00.000Z', ip: '203.0.113.1' }),
      book(env, pro, { client: BIA, startsAt: '2026-10-02T17:00:00.000Z', ip: '203.0.113.2' })
    ]);

    expect(results.map((result) => result.status)).toEqual(['confirmed', 'confirmed']);
  });

  it('keeps the 15 minute buffer between two bookings', async () => {
    asBooked(await book(env, pro, { client: ANA, startsAt: '2026-10-02T13:00:00.000Z' })); // 10:00-11:00 SP
    const tooClose = await book(env, pro, { client: BIA, startsAt: '2026-10-02T14:00:00.000Z' }); // 11:00 SP
    const enough = await book(env, pro, { client: BIA, startsAt: '2026-10-02T14:15:00.000Z' }); // 11:15 SP

    expect(tooClose.status).toBe('slotTaken');
    expect(enough.status).toBe('confirmed');
  });

  it('offers the next free starts when the time was taken', async () => {
    asBooked(await book(env, pro));
    const taken = await book(env, pro, { client: BIA });

    expect(taken.status).toBe('slotTaken');
    if (taken.status !== 'slotTaken') return;
    expect(taken.alternatives.length).toBeLessThanOrEqual(5);
    expect(taken.alternatives).not.toContain(FRIDAY_10);
    expect(taken.alternatives.every((start) => Date.parse(start) >= Date.parse(FRIDAY_10))).toBe(true);
  });

  it('never double books a cancelled slot twice and frees it again after a cancellation', async () => {
    const first = asBooked(await book(env, pro));
    await refs(env.deps.db).booking(first.bookingId).update({ status: 'cancelledByClient' });

    const second = await book(env, pro, { client: BIA });
    expect(second.status).toBe('confirmed');
  });
});

describe('createBooking: idempotency', () => {
  it('returns the same booking for a retry of the same request, with one more valid link and no second email', async () => {
    const key = randomUUID();
    const first = asBooked(await book(env, pro, { idempotencyKey: key, client: { ...ANA, email: 'ana@example.com' } }));
    const retry = asBooked(await book(env, pro, { idempotencyKey: key, client: { ...ANA, email: 'ana@example.com' } }));

    expect(retry.bookingId).toBe(first.bookingId);
    expect(retry.manageToken).not.toBe(first.manageToken);
    expect(retry.emailSent).toBe(false);
    expect(env.mail.sent).toHaveLength(1);
    expect((await refs(env.deps.db).bookings().get()).size).toBe(1);
    expect((await bookingDoc(env, first.bookingId)).manageTokenHashes).toHaveLength(2);
  });

  it('refuses the same key with a different request', async () => {
    const key = randomUUID();
    asBooked(await book(env, pro, { idempotencyKey: key }));

    await expect(book(env, pro, { idempotencyKey: key, startsAt: '2026-10-02T17:00:00.000Z' })).rejects.toMatchObject({
      code: 'CONFLICT'
    });
  });
});

describe('createBooking: pause, approval and no-show (D13, D15)', () => {
  it('is paused when the page does not accept bookings, with the return date when she gave one', async () => {
    const until = Date.parse('2026-10-20T12:00:00.000Z');
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.acceptingBookings': false, 'booking.pausedUntil': ts(until) });

    const outcome = await book(env, pro);

    expect(outcome).toEqual({ status: 'paused', pausedUntil: '2026-10-20T12:00:00.000Z' });
  });

  it('is paused until the return date and open again after it', async () => {
    await refs(env.deps.db)
      .profile(pro.slug)
      .update({ 'booking.pausedUntil': ts(Date.parse('2026-10-01T16:00:00.000Z')) });

    expect((await book(env, pro, { startsAt: '2026-10-02T13:00:00.000Z' })).status).toBe('paused');
    env.clock.set(Date.parse('2026-10-01T16:00:01.000Z'));
    expect((await book(env, pro, { startsAt: '2026-10-02T13:00:00.000Z', client: BIA })).status).toBe('confirmed');
  });

  it('waits for approval when she confirms new clients, but lets a returning phone book freely', async () => {
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.requiresApproval': true });

    const first = asBooked(await book(env, pro));
    expect(first.status).toBe('pendingApproval');
    expect((await bookingDoc(env, first.bookingId)).pendingReason).toBe('newClient');
    expect(await registrations()).toBe(0);

    // Once she approves the phone it is a client; the next booking is confirmed at once.
    await refs(env.deps.db)
      .contact(pro.uid, (await bookingDoc(env, first.bookingId)).phoneHash)
      .set({ ownerUid: pro.uid, phoneHash: (await bookingDoc(env, first.bookingId)).phoneHash, registered: true, bookingCount: 1, marks: [], onlineBookingStopped: false, createdAt: ts(0), updatedAt: ts(0) });
    const second = asBooked(await book(env, pro, { startsAt: '2026-10-02T17:00:00.000Z' }));
    expect(second.status).toBe('confirmed');
  });

  it('applies the no-show action when the limit is reached: approval, or a pause for that client only', async () => {
    const hash = (await (async () => {
      const done = asBooked(await book(env, pro, { startsAt: '2026-10-02T12:00:00.000Z' }));
      return (await bookingDoc(env, done.bookingId)).phoneHash;
    })());
    const marks = [1, 2, 3].map((n) => ({ id: `m${n}`, at: ts(Date.parse('2026-09-01T12:00:00.000Z') + n), kind: 'noShow' as const }));
    await refs(env.deps.db).contact(pro.uid, hash).update({ marks });

    const approval = asBooked(await book(env, pro, { startsAt: '2026-10-02T17:00:00.000Z' }));
    expect(approval.status).toBe('pendingApproval');
    expect((await bookingDoc(env, approval.bookingId)).pendingReason).toBe('noShowLimit');

    await refs(env.deps.db).availability(pro.uid).update({ 'noShow.action': 'pauseOnline' });
    expect((await book(env, pro, { startsAt: '2026-10-02T16:30:00.000Z' })).status).toBe('paused');
    // Somebody else is not paused: the limit follows the client, not the page.
    expect((await book(env, pro, { client: BIA, startsAt: '2026-10-02T21:00:00.000Z' })).status).toBe('confirmed');
  });

  it('pauses a client she stopped from online booking', async () => {
    const hash = (await bookingDoc(env, asBooked(await book(env, pro, { startsAt: '2026-10-02T12:00:00.000Z' })).bookingId)).phoneHash;
    await refs(env.deps.db).contact(pro.uid, hash).update({ onlineBookingStopped: true });

    expect((await book(env, pro, { startsAt: '2026-10-02T17:00:00.000Z' })).status).toBe('paused');
  });
});

describe('createBooking: the free registrations (D42)', () => {
  it('registers a new client whose booking is confirmed, once, and counts it', async () => {
    const outcome = asBooked(await book(env, pro));
    const stored = await bookingDoc(env, outcome.bookingId);

    expect(await registrations()).toBe(1);
    const contact = (await refs(env.deps.db).contact(pro.uid, stored.phoneHash).get()).data() as { registered: boolean; registrationId: string };
    expect(contact.registered).toBe(true);
    const ledger = await refs(env.deps.db).registrations(pro.uid).get();
    expect(ledger.size).toBe(1);
    expect(ledger.docs[0]?.data()).toMatchObject({ source: 'booking' });
    // The ledger holds an id and a date: no name, no phone.
    expect(JSON.stringify(ledger.docs[0]?.data())).not.toContain('Ana');
    expect(JSON.stringify(ledger.docs[0]?.data())).not.toContain(ANA.phone);
  });

  it('does not count the same phone twice when it books again', async () => {
    asBooked(await book(env, pro, { startsAt: '2026-10-02T12:00:00.000Z' }));
    asBooked(await book(env, pro, { startsAt: '2026-10-02T17:00:00.000Z' }));

    expect(await registrations()).toBe(1);
  });

  it('confirms the 10th new client and holds the 11th for approval when she has no plan', async () => {
    await setRegistrations(9);
    const tenth = asBooked(await book(env, pro, { startsAt: '2026-10-02T12:00:00.000Z' }));
    expect(tenth.status).toBe('confirmed');
    expect(await registrations()).toBe(10);

    const eleventh = asBooked(await book(env, pro, { client: BIA, startsAt: '2026-10-02T17:00:00.000Z' }));
    expect(eleventh.status).toBe('pendingApproval');
    expect((await bookingDoc(env, eleventh.bookingId)).pendingReason).toBe('freeRegistrationsUsed');
    expect(await registrations()).toBe(10);
  });

  it('lets a returning client keep booking after the free registrations are used', async () => {
    asBooked(await book(env, pro, { startsAt: '2026-10-02T12:00:00.000Z' }));
    await setRegistrations(10);

    const again = asBooked(await book(env, pro, { startsAt: '2026-10-02T17:00:00.000Z' }));

    expect(again.status).toBe('confirmed');
    expect(await registrations()).toBe(10);
  });

  it('confirms new clients beyond ten while she has an active plan, and keeps counting', async () => {
    await setRegistrations(10, { state: 'active', expiresAt: Date.parse('2027-10-01T00:00:00.000Z') });

    const outcome = asBooked(await book(env, pro, { client: BIA }));

    expect(outcome.status).toBe('confirmed');
    expect(await registrations()).toBe(11);
  });

  it('applies the limit again when the plan has lapsed, without touching existing clients', async () => {
    await setRegistrations(10, { state: 'active', expiresAt: Date.parse('2026-09-01T00:00:00.000Z') });

    const outcome = asBooked(await book(env, pro, { client: BIA }));

    expect(outcome.status).toBe('pendingApproval');
  });

  it('never registers two new clients past the limit when they book at the same moment', async () => {
    await setRegistrations(9);
    const results = await Promise.all([
      book(env, pro, { client: ANA, startsAt: '2026-10-02T12:00:00.000Z', ip: '203.0.113.1' }),
      book(env, pro, { client: BIA, startsAt: '2026-10-02T17:00:00.000Z', ip: '203.0.113.2' })
    ]);

    expect(results.map((result) => asBooked(result).status).sort()).toEqual(['confirmed', 'pendingApproval']);
    expect(await registrations()).toBe(10);
  }, 60_000);
});

describe('createBooking: holds', () => {
  it('keeps a held slot from other callers and lets the holder book it', async () => {
    const holdKey = 'hold-key-for-ana-0123456789';
    const held = await env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: FRIDAY_10, holdKey });
    expect(held).toMatchObject({ status: 'held' });

    expect((await book(env, pro, { client: BIA })).status).toBe('slotTaken');
    const mine = asBooked(await book(env, pro, { client: ANA, holdKey }));

    expect(mine.status).toBe('confirmed');
    expect((await refs(env.deps.db).holds().get()).size).toBe(0);
  });

  it('releases a hold when it expires', async () => {
    await env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: FRIDAY_10, holdKey: 'hold-key-for-ana-0123456789' });
    env.clock.advance(5 * 60_000 + 1);

    expect((await book(env, pro, { client: BIA })).status).toBe('confirmed');
  });
});

describe('createBooking: input and abuse', () => {
  it('stores a note and a guest COUNT only: no first-visit answers, no guest names, nothing it was not asked for (D45, D48)', async () => {
    const { createBooking } = await import('../../src/public/createBooking.js');
    const base = {
      slug: pro.slug,
      serviceId: SERVICE.glowFacial,
      startsAt: FRIDAY_10,
      client: { name: ANA.name, phone: ANA.phone, locale: 'pt-BR' },
      verification: { method: 'phone', idToken: env.phoneToken(ANA.phone) },
      idempotencyKey: randomUUID()
    };

    const rejected = await env
      .call(createBooking, {
        ...base,
        heardFrom: 'instagram',
        hadBefore: false,
        firstVisit: { heardFrom: 'friend', hadBefore: true },
        guests: ['Bia Lima', 'Carla'],
        guestNames: ['Bia Lima'],
        client: { ...base.client, heardFrom: 'instagram', firstVisit: true }
      })
      .catch((caught: unknown) => caught);
    expect(rejected).toBeInstanceOf(AppError);
    expect((rejected as AppError).code).toBe('INVALID_ARGUMENT');
    expect((rejected as AppError).details?.fields).toEqual(
      expect.arrayContaining(['heardFrom', 'hadBefore', 'firstVisit', 'guests', 'guestNames', 'client.heardFrom', 'client.firstVisit'])
    );
    expect(JSON.stringify((rejected as AppError).details)).not.toMatch(/instagram|friend|Bia|Carla/);

    const outcome = asBooked((await env.call(createBooking, { ...base, guests: 1, note: 'Prefiro de manha.' })) as Outcome);
    const stored = await bookingDoc(env, outcome.bookingId);
    expect(stored.guestCount).toBe(1);
    expect(stored.note).toBe('Prefiro de manha.');
    expect(Object.keys(stored).sort()).toEqual(
      [
        'addOns', 'client', 'createdAt', 'durationMinutes', 'endsAt', 'guestCount', 'manageTokenHashes', 'noShowPolicy', 'note', 'origin',
        'ownerUid', 'phoneHash', 'policy', 'purgeAt', 'rescheduleCount', 'rulesText', 'schemaVersion', 'serviceId', 'serviceName', 'slug',
        'startsAt', 'status', 'timeZoneID', 'updatedAt'
      ].sort()
    );
    expect(Object.keys(stored.client).sort()).toEqual(['locale', 'name', 'phone']);
    expect(JSON.stringify(stored)).not.toMatch(/heardFrom|hadBefore|firstVisit|guestNames|Bia|Carla/);
  });

  it('caps the note at 300 characters and drops an empty one', async () => {
    await expect(book(env, pro, { note: 'x'.repeat(301) })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT', details: { fields: ['note'] } });
    const outcome = asBooked(await book(env, pro, { note: '' }));
    expect((await bookingDoc(env, outcome.bookingId)).note).toBeUndefined();
  });

  it('rejects an unknown field, a bad phone and a bad time with field paths and no values', async () => {
    const error = await env
      .call((await import('../../src/public/createBooking.js')).createBooking, {
        slug: pro.slug,
        serviceId: SERVICE.glowFacial,
        startsAt: 'tomorrow',
        client: { name: 'Ana', phone: '5511', locale: 'pt-BR', healthNote: 'allergic to latex' },
        verification: { method: 'phone', idToken: 'x'.repeat(30) },
        idempotencyKey: randomUUID()
      })
      .catch((caught: unknown) => caught);

    expect(error).toBeInstanceOf(AppError);
    const details = (error as AppError).details;
    expect((error as AppError).code).toBe('INVALID_ARGUMENT');
    expect(details?.fields).toEqual(expect.arrayContaining(['startsAt', 'client.phone', 'client.healthNote']));
    expect(JSON.stringify(details)).not.toContain('latex');
  });

  it('limits one phone to five attempts an hour and says when to retry', async () => {
    for (let attempt = 0; attempt < 5; attempt += 1) {
      await book(env, pro, { startsAt: '2026-10-02T13:07:00.000Z', ip: `203.0.113.${attempt}` });
    }
    const error = await book(env, pro, { startsAt: '2026-10-02T13:07:00.000Z', ip: '203.0.113.99' }).catch((caught: unknown) => caught);

    expect((error as AppError).code).toBe('RATE_LIMITED');
    expect(Number((error as AppError).details?.retryAfterSeconds)).toBeGreaterThan(0);
  });

  it('limits one address to ten attempts an hour', async () => {
    for (let attempt = 0; attempt < 10; attempt += 1) {
      await book(env, pro, {
        client: { name: 'N', phone: `+55119111100${String(attempt).padStart(2, '0')}`, email: undefined },
        startsAt: '2026-10-02T13:07:00.000Z',
        ip: '192.0.2.50'
      });
    }
    const error = await book(env, pro, { client: BIA, startsAt: '2026-10-02T13:07:00.000Z', ip: '192.0.2.50' }).catch((caught: unknown) => caught);

    expect((error as AppError).code).toBe('RATE_LIMITED');
  });
});
