import { randomUUID } from 'node:crypto';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { refs, ts } from '../../src/lib/store.js';
import { registerManualBooking } from '../../src/owner/registerManualBooking.js';
import { moveBookingByOwner } from '../../src/owner/moveBookingByOwner.js';
import { getSlots } from '../../src/public/getSlots.js';
import { cancelBooking } from '../../src/token/cancelBooking.js';
import { rebook } from '../../src/token/rebook.js';
import { ANA, BIA, asBooked, book, bookingDoc } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { captureWorld, ownerContext, restoreWorld, seedProfessional, SERVICE } from '../support/seed.js';
import type { Professional, World } from '../support/seed.js';

const env = createTestEnv();
const START = '2026-10-03T13:00:00.000Z';
const END = '2026-10-03T14:00:00.000Z';
let pro: Professional;
let world: World;

beforeAll(async () => {
  await resetEmulators(env);
  pro = await seedProfessional(env);
  world = await captureWorld(env, pro);
});

beforeEach(async () => {
  await resetEmulators(env);
  env.clock.set(Date.UTC(2026, 9, 1, 15));
  env.mail.sent.length = 0;
  await restoreWorld(env, world);
});

async function manual() {
  const result = await env.call(registerManualBooking, {
    appointmentId: randomUUID(),
    serviceName: 'Glow Facial + Hydration mask',
    startsAt: START,
    endsAt: END,
    timeZoneID: 'America/Sao_Paulo',
    client: { ...ANA, email: 'ana@example.com', locale: 'pt-BR' }
  }, ownerContext(pro.uid)) as { bookingId: string; url: string };
  return { ...result, token: result.url.split('/m/')[1] ?? '' };
}

async function slots(token?: string): Promise<string[]> {
  const result = await env.call(getSlots, {
    slug: pro.slug, serviceId: SERVICE.glowFacial,
    from: '2026-10-03', to: '2026-10-03',
    ...(token ? { rescheduleToken: token } : {})
  }) as { days: { slots: string[]; more?: string[] }[] };
  return result.days.flatMap(day => [...day.slots, ...(day.more ?? [])]);
}

describe('functional audit: manual/web scheduling parity', () => {
  it('F05: the manual booking keeps its service, extras, guests and processing snapshot', async () => {
    const appointmentId = randomUUID();
    const addOnId = randomUUID();
    await env.call(registerManualBooking, {
      appointmentId, serviceId: SERVICE.glowFacial, serviceName: 'Glow Facial', serviceMinutes: 60,
      addOns: [{ id: addOnId, name: 'Mask', minutes: 10 }], guestCount: 1,
      timing: { prepMinutes: 10, cleanupMinutes: 5, processingStartMinutes: 20, processingMinutes: 15 },
      startsAt: START, endsAt: '2026-10-03T15:10:00.000Z', timeZoneID: 'America/Sao_Paulo',
      client: { ...ANA, email: 'ana@example.com', locale: 'pt-BR' }
    }, ownerContext(pro.uid));
    const stored = await bookingDoc(env, appointmentId);
    expect(stored.serviceId).toBe(SERVICE.glowFacial);
    expect(stored.addOns).toEqual([{ id: addOnId, name: 'Mask', minutes: 10 }]);
    expect(stored.guestCount).toBe(1);
    expect(stored).toMatchObject({ prepMinutes: 10, cleanupMinutes: 5,
      processingStartMinutes: 20, processingMinutes: 15 });
  });

  it('F05: inconsistent manual booking details cannot claim a shorter time', async () => {
    await expect(env.call(registerManualBooking, {
      appointmentId: randomUUID(), serviceId: SERVICE.glowFacial, serviceName: 'Glow Facial', serviceMinutes: 60,
      addOns: [], guestCount: 1, startsAt: START, endsAt: END, timeZoneID: 'America/Sao_Paulo',
      client: { ...ANA, locale: 'pt-BR' }
    }, ownerContext(pro.uid))).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('F01: a published manual visit can register itself, but another visit cannot take its time', async () => {
    const appointmentId = randomUUID();
    await refs(env.deps.db).availability(pro.uid).update({
      busy: [{ start: ts(Date.parse(START)), end: ts(Date.parse(END)), kind: 'appointment', appointmentId }]
    });
    await env.call(registerManualBooking, {
      appointmentId, serviceName: 'Glow Facial', startsAt: START, endsAt: END,
      timeZoneID: 'America/Sao_Paulo', client: { ...ANA, email: 'ana@example.com', locale: 'pt-BR' }
    }, ownerContext(pro.uid));
    expect((await bookingDoc(env, appointmentId)).status).toBe('confirmed');
    await expect(manual()).rejects.toMatchObject({ code: 'CONFLICT' });
  });

  it('CONTROL: two public clients cannot book overlapping visits', async () => {
    const outcomes = await Promise.all([
      book(env, pro, { startsAt: START, client: ANA, ip: '203.0.113.1' }),
      book(env, pro, { startsAt: START, client: BIA, ip: '203.0.113.2' })
    ]);
    expect(outcomes.filter(result => result.status === 'confirmed')).toHaveLength(1);
  });

  it('F01: manual registration must reject a time already booked online', async () => {
    asBooked(await book(env, pro, { startsAt: START, client: BIA }));
    let rejected = false;
    try { await manual(); } catch { rejected = true; }
    expect(rejected, 'manual registration accepted a second active booking in an occupied interval').toBe(true);
  });

  it('F01: owner move must not put one active visit on top of another', async () => {
    const first = asBooked(await book(env, pro, { startsAt: START }));
    const second = asBooked(await book(env, pro, { startsAt: '2026-10-03T17:00:00.000Z', client: BIA }));
    try {
      await env.call(moveBookingByOwner, { bookingId: second.bookingId, startsAt: START }, ownerContext(pro.uid));
    } catch { /* A refusal satisfies the guarantee; examine the stored interval either way. */ }
    const a = await bookingDoc(env, first.bookingId);
    const b = await bookingDoc(env, second.bookingId);
    expect(b.startsAt.toMillis() >= a.endsAt.toMillis() || b.endsAt.toMillis() <= a.startsAt.toMillis()).toBe(true);
  });

  it('F03: a manual visit duplicated in anonymous busy must not block its own current time', async () => {
    const booked = await manual();
    await refs(env.deps.db).availability(pro.uid).update({
      busy: [{ start: (await bookingDoc(env, booked.bookingId)).startsAt,
        end: (await bookingDoc(env, booked.bookingId)).endsAt, kind: 'appointment', appointmentId: booked.bookingId }]
    });
    expect(await slots(booked.token)).toContain(START);
  });

  it('F03: cancelling a registered manual visit must release its published interval', async () => {
    const booked = await manual();
    const stored = await bookingDoc(env, booked.bookingId);
    await refs(env.deps.db).availability(pro.uid).update({
      busy: [{ start: stored.startsAt, end: stored.endsAt, kind: 'appointment', appointmentId: booked.bookingId }]
    });
    await env.call(cancelBooking, { token: booked.token });
    expect(await slots()).toContain(START);
  });

  it('F05: manual registration must retain the no-show policy used to describe late cancellation', async () => {
    const booked = await manual();
    expect((await bookingDoc(env, booked.bookingId)).noShowPolicy).toBeDefined();
  });

  it('F06: the actual web reschedule request must accept the service id returned for a manual booking', async () => {
    const booked = await manual();
    const stored = await bookingDoc(env, booked.bookingId);
    let succeeded = false;
    try {
      await env.call(getSlots, {
        slug: pro.slug, serviceId: stored.serviceId, rescheduleToken: booked.token,
        from: '2026-10-03', to: '2026-10-03'
      });
      succeeded = true;
    } catch { /* The web uses the booking's service id without substituting an offered UUID. */ }
    expect(succeeded, 'manual service id is rejected before the reschedule token is evaluated').toBe(true);
  });

  it('F07: rebooking through the web must retain the guests used to request available times', async () => {
    const original = asBooked(await book(env, pro, { startsAt: START, guests: 1 }));
    const result = asBooked(await env.call(rebook, {
      token: original.manageToken, serviceId: SERVICE.glowFacial, addOnIds: [],
      startsAt: '2026-10-06T13:00:00.000Z', idempotencyKey: randomUUID()
    }) as Awaited<ReturnType<typeof book>>);
    expect((await bookingDoc(env, result.bookingId)).guestCount).toBe(1);
    expect(Date.parse(result.endsAt) - Date.parse(result.startsAt)).toBe(120 * 60_000);
  });

  it('CONTROL: cancelling a web booking releases the time without a phone refresh', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));
    await env.call(cancelBooking, { token: booked.manageToken });
    expect(await slots()).toContain(START);
  });
});
