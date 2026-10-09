import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { refs, ts } from '../../src/lib/store.js';
import { getHold } from '../../src/public/getHold.js';
import { getPublicPage } from '../../src/public/getPublicPage.js';
import { getSlots } from '../../src/public/getSlots.js';
import { holdSlot } from '../../src/public/holdSlot.js';
import { publishAvailability } from '../../src/owner/publishAvailability.js';
import { asBooked, BIA, book } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { ADDON, FRIDAY_10, mariaAvailability, ownerContext, SERVICE, seedProfessional, captureWorld, restoreWorld } from '../support/seed.js';
import type { Professional, World } from '../support/seed.js';

const env = createTestEnv();
let pro: Professional;
let world: World;

interface SlotsResponse {
  timeZoneID: string;
  durationMinutes: number;
  paused: boolean;
  days: { date: string; slots: string[] }[];
}

const slotsFor = async (input: Record<string, unknown>): Promise<SlotsResponse> =>
  (await env.call(getSlots, { slug: pro.slug, serviceId: SERVICE.glowFacial, from: '2026-10-02', to: '2026-10-02', ...input })) as SlotsResponse;

beforeAll(async () => {
  await resetEmulators(env);
  pro = await seedProfessional(env);
  world = await captureWorld(env, pro);
});

beforeEach(async () => {
  await resetEmulators(env);
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  await restoreWorld(env, world);
});

describe('getPublicPage', () => {
  it('returns the published page without the health form, the feature flags and the SMS countries', async () => {
    const page = (await env.call(getPublicPage, { slug: pro.slug })) as {
      profile: { displayName: string; slug: string; inboxKey: { keyId: string }; services: unknown[] };
      intakeAvailable: boolean;
      features: { whatsAppAutomation: boolean; smsCallingCodes: string[] };
    };

    expect(page.profile.displayName).toBe('Maria Souza');
    expect(page.profile.slug).toBe('maria');
    expect(page.profile.inboxKey.keyId).toBe(pro.inboxKey.keyId);
    expect(page.profile.services).toHaveLength(3);
    expect(page.intakeAvailable).toBe(false);
    expect(page.features.whatsAppAutomation).toBe(false);
    expect(page.features.smsCallingCodes).toContain('55');
    expect(JSON.stringify(page)).not.toContain('ownerUid');
    expect(JSON.stringify(page)).not.toContain(pro.uid);
  });

  it('answers NOT_FOUND for an unknown address', async () => {
    await expect(env.call(getPublicPage, { slug: 'nobody' })).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('getSlots', () => {
  it('offers the starts around lunch on a working day, in the business time zone', async () => {
    const result = await slotsFor({ guests: 0 });
    const times = result.days[0]?.slots.map((slot) => new Date(Date.parse(slot) - 3 * 3_600_000).toISOString().slice(11, 16));

    expect(result.timeZoneID).toBe('America/Sao_Paulo');
    expect(result.durationMinutes).toBe(60);
    expect(result.paused).toBe(false);
    expect(times?.[0]).toBe('09:00');
    expect(times).toContain('11:30');
    expect(times).not.toContain('12:00');
    expect(times).not.toContain('12:30');
    expect(times).toContain('13:30');
    expect(times?.at(-1)).toBe('18:00');
  });

  it('uses the total time of add-ons and guests (D19)', async () => {
    const result = await slotsFor({ addOnIds: [ADDON.mask], guests: 1 });

    expect(result.durationMinutes).toBe(135);
    const times = result.days[0]?.slots.map((slot) => new Date(Date.parse(slot) - 3 * 3_600_000).toISOString().slice(11, 16));
    expect(times?.at(-1)).toBe('16:45'); // 16:45 + 2h15 = 19:00
  });

  it('returns one entry per day of the range, empty on closed days and in the past', async () => {
    const result = await slotsFor({ from: '2026-09-30', to: '2026-10-05' });

    expect(result.days.map((day) => day.date)).toEqual(['2026-09-30', '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05']);
    expect(result.days[0]?.slots).toEqual([]); // yesterday
    expect(result.days[2]?.slots.length).toBeGreaterThan(0); // Friday
    expect(result.days[4]?.slots).toEqual([]); // Sunday
    expect(result.days[5]?.slots).toEqual([]); // Monday
  });

  it('hides times that are booked, held or blocked, and her own hold does not block her', async () => {
    asBooked(await book(env, pro, { startsAt: FRIDAY_10 })); // 10:00-11:00 SP
    const holdKey = 'hold-key-for-bia-0123456789';
    await env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: '2026-10-02T17:00:00.000Z', holdKey });
    await env.call(publishAvailability, mariaAvailability({
      busy: [{ startsAt: '2026-10-02T20:00:00.000Z', endsAt: '2026-10-02T21:00:00.000Z', kind: 'block' }]
    }), ownerContext(pro.uid));

    const others = (await slotsFor({})).days[0]?.slots ?? [];
    const mine = (await slotsFor({ holdKey })).days[0]?.slots ?? [];

    expect(others).not.toContain(FRIDAY_10);
    expect(others).not.toContain('2026-10-02T13:30:00.000Z'); // inside the 15 minute buffer after the booking
    expect(others).toContain('2026-10-02T14:15:00.000Z');
    expect(others).not.toContain('2026-10-02T17:00:00.000Z'); // held by somebody else
    expect(mine).toContain('2026-10-02T17:00:00.000Z'); // her own hold
    expect(others).not.toContain('2026-10-02T20:00:00.000Z'); // her own block
    expect(others).toContain('2026-10-02T21:00:00.000Z'); // a block has no buffer
  });

  it('keeps a buffer around a manual appointment she published, and none around a block', async () => {
    await env.call(publishAvailability, mariaAvailability({
      busy: [{ startsAt: '2026-10-02T13:00:00.000Z', endsAt: '2026-10-02T14:00:00.000Z', kind: 'appointment' }]
    }), ownerContext(pro.uid));

    const slots = (await slotsFor({})).days[0]?.slots ?? [];

    expect(slots).not.toContain('2026-10-02T14:00:00.000Z');
    expect(slots).toContain('2026-10-02T14:15:00.000Z');
  });

  it('is empty and marked paused when the page does not accept bookings', async () => {
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.acceptingBookings': false });

    const result = await slotsFor({});

    expect(result.paused).toBe(true);
    expect(result.days[0]?.slots).toEqual([]);
  });

  it('computes the slots of a booking being moved without its own time blocking it', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: FRIDAY_10 }));

    const without = (await slotsFor({})).days[0]?.slots ?? [];
    const moving = (await slotsFor({ rescheduleToken: booked.manageToken })).days[0]?.slots ?? [];

    expect(without).not.toContain(FRIDAY_10);
    expect(moving).toContain(FRIDAY_10);
    expect(moving).toContain('2026-10-02T13:15:00.000Z');
  });

  it('refuses a reschedule token of another professional', async () => {
    const other = await seedProfessional(env, { uid: 'pro-bia', slug: 'bia-beauty' });
    const booked = asBooked(await book(env, other, { startsAt: FRIDAY_10, slug: other.slug, client: BIA }));

    await expect(slotsFor({ rescheduleToken: booked.manageToken })).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('is empty before the professional publishes her availability', async () => {
    await refs(env.deps.db).availability(pro.uid).delete();

    expect((await slotsFor({})).days[0]?.slots).toEqual([]);
  });

  it('rejects a range of more than 42 days or one that runs backwards', async () => {
    await expect(slotsFor({ from: '2026-10-01', to: '2026-12-01' })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(slotsFor({ from: '2026-10-05', to: '2026-10-01' })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('answers NOT_FOUND for an unknown service', async () => {
    await expect(slotsFor({ serviceId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' })).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('does not offer a day beyond the booking window', async () => {
    const result = await slotsFor({ from: '2026-12-01', to: '2026-12-01' });

    expect(result.days[0]?.slots).toEqual([]);
  });
});

describe('holdSlot and getHold', () => {
  it('holds a free time for five minutes and replaces the previous hold of the same key', async () => {
    const holdKey = 'hold-key-for-ana-0123456789';
    const first = (await env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: FRIDAY_10, holdKey })) as { status: string; expiresAt: string };
    await env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: '2026-10-02T17:00:00.000Z', holdKey });

    expect(first.status).toBe('held');
    expect(first.expiresAt).toBe('2026-10-01T15:05:00.000Z');
    expect((await refs(env.deps.db).holds().get()).size).toBe(1);
  });

  it('tells a second caller the time is taken and which times are next', async () => {
    await env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: FRIDAY_10, holdKey: 'hold-key-for-ana-0123456789' });

    const second = (await env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: FRIDAY_10, holdKey: 'hold-key-for-bia-0123456789' })) as {
      status: string;
      alternatives: string[];
    };

    expect(second.status).toBe('slotTaken');
    expect(second.alternatives.length).toBeGreaterThan(0);
  });

  it('is paused when the page is', async () => {
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.acceptingBookings': false });

    expect(await env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: FRIDAY_10, holdKey: 'hold-key-for-ana-0123456789' })).toEqual({ status: 'paused' });
  });

  it('opens a waitlist offer by its key until it expires', async () => {
    const holdKey = 'offer-key-0123456789abcdef';
    await refs(env.deps.db).hold('h1').set({
      ownerUid: pro.uid, slug: pro.slug, serviceId: SERVICE.glowFacial, addOnIds: [], guests: 0,
      startsAt: ts(Date.parse(FRIDAY_10)), endsAt: ts(Date.parse(FRIDAY_10) + 3_600_000), expiresAt: ts(env.clock.now() + 3_600_000),
      holdKeyHash: (await import('../../src/lib/holds.js')).holdKeyHash(holdKey), kind: 'offer'
    });

    const hold = await env.call(getHold, { slug: pro.slug, holdKey });
    expect(hold).toMatchObject({ serviceId: SERVICE.glowFacial, startsAt: FRIDAY_10 });

    env.clock.advance(2 * 3_600_000);
    await expect(env.call(getHold, { slug: pro.slug, holdKey })).rejects.toMatchObject({ code: 'TOKEN_EXPIRED' });
    await expect(env.call(getHold, { slug: pro.slug, holdKey: 'some-other-key-0123456789' })).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});
