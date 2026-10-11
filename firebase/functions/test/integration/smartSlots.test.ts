import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import type { AvailabilityDoc, ProfileService, PublicProfileDoc, TimingFields, WaitlistDoc } from '../../src/lib/docs.js';
import { refs } from '../../src/lib/store.js';
import { waitlistMatchesFor } from '../../src/lib/waitlistMatch.js';
import { publishAvailability } from '../../src/owner/publishAvailability.js';
import { getSlots } from '../../src/public/getSlots.js';
import { holdSlot } from '../../src/public/holdSlot.js';
import { joinWaitlist } from '../../src/public/joinWaitlist.js';
import { cancelBooking } from '../../src/token/cancelBooking.js';
import { rescheduleBooking } from '../../src/token/rescheduleBooking.js';
import { asBooked, BIA, book, bookingDoc } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { captureWorld, FRIDAY_10, mariaAvailability, ownerContext, restoreWorld, SERVICE, seedProfessional } from '../support/seed.js';
import type { AvailabilityInput } from '../../src/contracts/profile.js';
import type { Professional, World } from '../support/seed.js';

// D56 against the emulators: Maria works 09:00 to 19:00 in São Paulo (UTC-3) with lunch 12:30 to 13:30 and a 15 minute
// buffer; her services are 60, 90 and 75 minutes, so her shortest offer is 60 and a gap shorter than 75 is dead.

const env = createTestEnv();
let pro: Professional;
let world: World;

interface Day {
  date: string;
  slots: string[];
  more?: string[];
}

/** Friday 2026-10-02 at a São Paulo wall-clock time, as an instant. */
const friday = (clock: string): string => {
  const [hours, minutes] = clock.split(':').map(Number);
  return new Date(Date.UTC(2026, 9, 2, (hours ?? 0) + 3, minutes ?? 0)).toISOString();
};

const dayOf = async (serviceId: string, extra: Record<string, unknown> = {}): Promise<Day> => {
  const response = (await env.call(getSlots, { slug: pro.slug, serviceId, from: '2026-10-02', to: '2026-10-02', ...extra })) as {
    days: Day[];
  };
  const day = response.days[0];
  if (!day) throw new Error('no day');
  return day;
};
const freeOf = (day: Day): string[] => [...day.slots, ...(day.more ?? [])].sort();

const publish = async (overrides: Partial<AvailabilityInput>): Promise<void> => {
  await env.call(publishAvailability, mariaAvailability(overrides), ownerContext(pro.uid));
};

/** Gives one of her published services an extra or processing time, as the app publishes it. */
const shapeService = async (serviceId: string, timing: TimingFields): Promise<void> => {
  const ref = refs(env.deps.db).profile(pro.slug);
  const profile = (await ref.get()).data() as PublicProfileDoc;
  const services: ProfileService[] = profile.services.map((service) => (service.id === serviceId ? { ...service, ...timing } : service));
  await ref.update({ services });
};

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

describe('getSlots with smart slots (D56)', () => {
  it('anchors a 75 minute service right after a visit and keeps the off-grid times behind "Show all times"', async () => {
    await publish({ slotStepMinutes: 30, busy: [{ startsAt: friday('09:35'), endsAt: friday('10:05'), kind: 'appointment' }] });

    const day = await dayOf(SERVICE.deepCleansing);

    expect(day.slots).toContain(friday('10:20')); // 10:05 + the 15 minute buffer, though the grid says 10:30
    expect(day.slots).not.toContain(friday('10:30')); // it would leave 10 minutes nobody can book
    expect(day.more).toContain(friday('10:30'));
    const held = (await env.call(holdSlot, {
      slug: pro.slug,
      serviceId: SERVICE.deepCleansing,
      startsAt: friday('10:30'),
      holdKey: 'smart-slots-hold-key-0123456789'
    })) as { status: string };
    expect(held.status).toBe('held'); // any free start can be booked, recommended or not
  });

  it('shows every free start and no "more" when she switches the compact day off', async () => {
    await publish({ slotStepMinutes: 30, compactDay: false, busy: [{ startsAt: friday('09:35'), endsAt: friday('10:05'), kind: 'appointment' }] });

    const day = await dayOf(SERVICE.deepCleansing);

    expect(day.slots).toEqual(expect.arrayContaining([friday('10:20'), friday('10:30')]));
    expect(day.more).toBeUndefined();
  });

  it('"match the service" tiles the day with whole visits plus the buffer', async () => {
    await publish({ slotStepMinutes: 0 });

    const free = freeOf(await dayOf(SERVICE.deepCleansing));

    expect(free).toEqual(expect.arrayContaining([friday('09:00'), friday('10:30'), friday('11:15'), friday('13:30')]));
    expect(free).not.toContain(friday('09:15'));
  });

  it('stores the slot step, the compact day and the shape of her own appointments, and none for a block', async () => {
    await publish({
      slotStepMinutes: 20,
      compactDay: false,
      busy: [
        { startsAt: friday('15:00'), endsAt: friday('16:00'), kind: 'appointment', cleanupMinutes: 10, processingStartMinutes: 15, processingMinutes: 30 },
        { startsAt: friday('17:00'), endsAt: friday('18:00'), kind: 'block', prepMinutes: 5 }
      ]
    });

    const doc = (await refs(env.deps.db).availability(pro.uid).get()).data() as AvailabilityDoc;

    expect(doc.slotStepMinutes).toBe(20);
    expect(doc.compactDay).toBe(false);
    expect(doc.busy[0]).toMatchObject({ kind: 'appointment', cleanupMinutes: 10, processingStartMinutes: 15, processingMinutes: 30 });
    expect(doc.busy[1]?.prepMinutes).toBeUndefined();
  });

  it('a visit inside her processing time from the page: free from the page and bookable', async () => {
    await publish({ busy: [{ startsAt: friday('15:00'), endsAt: friday('16:30'), kind: 'appointment', processingStartMinutes: 20, processingMinutes: 60 }] });

    const free = freeOf(await dayOf(SERVICE.glowFacial));

    expect(free).toContain(friday('15:20'));
    expect(free).not.toContain(friday('15:30'));
  });
});

describe('extra and processing time on bookings (D56)', () => {
  it('snapshots the service\'s extra time on the booking and keeps the next visit away from it', async () => {
    await shapeService(SERVICE.deepCleansing, { prepMinutes: 10, cleanupMinutes: 15 });

    const booked = asBooked(await book(env, pro, { serviceId: SERVICE.deepCleansing, startsAt: friday('15:00') }));
    const doc = await bookingDoc(env, booked.bookingId);
    const free = freeOf(await dayOf(SERVICE.glowFacial));

    expect(doc).toMatchObject({ durationMinutes: 75, prepMinutes: 10, cleanupMinutes: 15 });
    expect(booked.endsAt).toBe(friday('16:15')); // the visible end: extra time is not part of the visit
    expect(free).toContain(friday('16:45')); // 16:15 + 15 clean-up + 15 buffer
    expect(free).not.toContain(friday('16:30'));
    expect(free).not.toContain(friday('13:45')); // ends 14:45, inside the 10 minute prep plus the buffer before 15:00
    expect(free).toContain(friday('13:30'));
  });

  it('books a visit inside another visit\'s processing time, and refuses one that does not fit in it', async () => {
    await shapeService(SERVICE.brazilianGlow, { processingStartMinutes: 20, processingMinutes: 60 });
    asBooked(await book(env, pro, { serviceId: SERVICE.brazilianGlow, startsAt: FRIDAY_10 })); // 10:00-11:30

    const inner = await book(env, pro, { serviceId: SERVICE.glowFacial, startsAt: friday('10:20'), client: BIA });
    const late = await book(env, pro, {
      serviceId: SERVICE.glowFacial,
      startsAt: friday('10:30'),
      client: { name: 'Carla Dias', phone: '+5511965432109', email: undefined }
    });

    expect(inner.status).toBe('confirmed');
    expect(late.status).toBe('slotTaken');
  });

  it('a rescheduled booking keeps its own extra time', async () => {
    env.clock.set(Date.UTC(2026, 8, 29, 15, 0)); // well outside the 24 hour window, so the move is direct
    await shapeService(SERVICE.deepCleansing, { cleanupMinutes: 30 });
    const booked = asBooked(await book(env, pro, { serviceId: SERVICE.deepCleansing, startsAt: FRIDAY_10 }));
    await shapeService(SERVICE.deepCleansing, { cleanupMinutes: 0 }); // a later edit does not change the booking

    const moved = (await env.call(rescheduleBooking, { token: booked.manageToken, startsAt: friday('15:00') })) as { status: string };
    const free = freeOf(await dayOf(SERVICE.glowFacial));

    expect(moved.status).toBe('moved');
    expect(free).not.toContain(friday('16:30')); // 16:15 + 30 clean-up + 15 buffer = 17:00
    expect(free).toContain(friday('17:00'));
  });
});

describe('waitlist with smart slots (D56)', () => {
  it('offers a freed time only to people whose service now has a free start that uses it', async () => {
    // Around Ana's 10:00-11:00 visit the day is full: after she cancels, 10:00 to 11:00 is the only free hour.
    await publish({
      busy: [
        { startsAt: friday('09:00'), endsAt: friday('09:45'), kind: 'appointment' },
        { startsAt: friday('11:15'), endsAt: friday('12:30'), kind: 'appointment' },
        { startsAt: friday('13:30'), endsAt: friday('19:00'), kind: 'block' }
      ]
    });
    const booked = asBooked(await book(env, pro, { startsAt: FRIDAY_10 }));
    const join = { slug: pro.slug, locale: 'pt-BR', dayFrom: '2026-10-02', dayTo: '2026-10-02' };
    await env.call(joinWaitlist, { ...join, name: 'Paula', phone: '+5511955550000', serviceId: SERVICE.brazilianGlow });
    await env.call(joinWaitlist, { ...join, name: 'Bia', phone: BIA.phone, serviceId: SERVICE.glowFacial });

    await env.call(cancelBooking, { token: booked.manageToken, acceptLateWarning: true });
    const matches = await waitlistMatchesFor(env.deps, await bookingDoc(env, booked.bookingId));

    expect(matches.map((entry: WaitlistDoc) => entry.name)).toEqual(['Bia']);
  });
});
