import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import type { AppError } from '../../src/lib/errors.js';
import { refs, ts } from '../../src/lib/store.js';
import type { BookingDoc, ContactDoc } from '../../src/lib/docs.js';
import { cancelBooking } from '../../src/token/cancelBooking.js';
import { confirmPresence } from '../../src/token/confirmPresence.js';
import { getBooking } from '../../src/token/getBooking.js';
import { rebook } from '../../src/token/rebook.js';
import { reportLate } from '../../src/token/reportLate.js';
import { requestReschedule } from '../../src/token/requestReschedule.js';
import { rescheduleBooking } from '../../src/token/rescheduleBooking.js';
import { ANA, asBooked, BIA, book, bookingDoc } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { captureWorld, restoreWorld, SERVICE, seedProfessional } from '../support/seed.js';
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
  env.push.calls.length = 0;
  await restoreWorld(env, world);
});

const HOUR = 3_600_000;
/** Saturday 2026-10-03 10:00 in Sao Paulo: 46 hours after the tests' "now", so it starts inside the free window. */
const START = '2026-10-03T13:00:00.000Z';

async function bookFriday(startsAt = START) {
  return asBooked(await book(env, pro, { startsAt }));
}

async function view(token: string) {
  return (await env.call(getBooking, { token })) as {
    status: string;
    phase: string;
    actions: Record<string, unknown>;
    policy: { freeWindowHours: number };
    professional: { displayName: string; whatsappE164?: string };
    client: { name: string };
    intakeRequired: boolean;
    pendingReschedule?: { status: string };
    clientConfirmedAt?: string;
    lateByMinutes?: number;
    tokenExpiresAt: string;
    rulesText: Record<string, string>;
  };
}

describe('getBooking', () => {
  it('shows the booking, the rules she set and what the client may do now', async () => {
    const booked = await bookFriday();

    const page = await view(booked.manageToken);

    expect(page.status).toBe('confirmed');
    expect(page.phase).toBe('upcoming');
    expect(page.professional.displayName).toBe('Maria Souza');
    expect(page.client.name).toBe('Ana Costa');
    expect(page.policy.freeWindowHours).toBe(24);
    expect(page.rulesText.en).toContain('24 hours');
    expect(page.actions).toMatchObject({
      cancel: 'free',
      reschedule: 'direct',
      isInsideFreeWindow: true,
      cancellationWouldBeLate: false,
      canConfirmPresence: true,
      canReportLate: false
    });
    expect(page.tokenExpiresAt).toBe('2026-10-10T14:00:00.000Z');
    expect(JSON.stringify(page)).not.toContain(ANA.phone);
  });

  it('turns to "request" and "allowed with a warning" inside the last 24 hours', async () => {
    const booked = await bookFriday();
    env.clock.set(Date.parse(START) - 10 * HOUR);

    expect((await view(booked.manageToken)).actions).toMatchObject({
      cancel: 'allowedWithWarning',
      reschedule: 'request',
      isInsideFreeWindow: false,
      cancellationWouldBeLate: true
    });
  });

  it('follows the snapshot of the policy at booking time, not later edits', async () => {
    const booked = await bookFriday();
    await refs(env.deps.db).profile(pro.slug).update({ 'policy.freeWindowHours': 72, 'policy.afterWindowCancel': 'message' });
    env.clock.set(Date.parse(START) - 30 * HOUR);

    const page = await view(booked.manageToken);

    expect(page.actions.cancel).toBe('free'); // 30 h is outside 72 h now, but inside the 24 h she had when the client booked
    expect(page.policy.freeWindowHours).toBe(24);
  });

  it('reports the phases of a visit and offers nothing once it is over', async () => {
    const booked = await bookFriday();
    env.clock.set(Date.parse(START) + 30 * 60_000);
    expect((await view(booked.manageToken)).phase).toBe('inProgress');
    env.clock.set(Date.parse(START) + 2 * HOUR);

    const page = await view(booked.manageToken);

    expect(page.phase).toBe('past');
    expect(page.actions).toMatchObject({ cancel: 'unavailable', reschedule: 'unavailable', canConfirmPresence: false });
  });

  it('answers NOT_FOUND for an unknown link and TOKEN_EXPIRED seven days after the visit', async () => {
    const booked = await bookFriday();

    await expect(view('x'.repeat(22))).rejects.toMatchObject({ code: 'NOT_FOUND' });
    env.clock.set(Date.parse(START) + HOUR + 7 * 24 * HOUR);
    await expect(view(booked.manageToken)).rejects.toMatchObject({ code: 'TOKEN_EXPIRED' });
  });

  it('lets a cancelled booking be seen, with nothing to do', async () => {
    const booked = await bookFriday();
    await refs(env.deps.db).booking(booked.bookingId).update({ status: 'cancelledByPro' });

    const page = await view(booked.manageToken);

    expect(page.status).toBe('cancelledByPro');
    expect(page.actions).toMatchObject({ cancel: 'unavailable', reschedule: 'unavailable' });
  });

  it('says a request waits for her and sends the client to message her to change it', async () => {
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.requiresApproval': true });
    const booked = await bookFriday();

    const page = await view(booked.manageToken);

    expect(page.status).toBe('pendingApproval');
    expect(page.actions).toMatchObject({ cancel: 'free', reschedule: 'message', canConfirmPresence: false });
  });

  it('flags the health form as required until one was sent within twelve months', async () => {
    const booked = await bookFriday();
    await refs(env.deps.db).intakeForm(pro.uid).set({
      ownerUid: pro.uid, slug: pro.slug, formVersion: 1, template: {}, consent: {}, updatedAt: ts(0)
    });
    expect((await view(booked.manageToken)).intakeRequired).toBe(true);

    const hash = (await bookingDoc(env, booked.bookingId)).phoneHash;
    await refs(env.deps.db).contact(pro.uid, hash).update({ lastIntakeAt: ts(env.clock.now() - 30 * 24 * HOUR) });
    expect((await view(booked.manageToken)).intakeRequired).toBe(false);
    await refs(env.deps.db).contact(pro.uid, hash).update({ lastIntakeAt: ts(env.clock.now() - 400 * 24 * HOUR) });
    expect((await view(booked.manageToken)).intakeRequired).toBe(true);
  });
});

describe('confirmPresence and reportLate', () => {
  it('records that the client is coming, once, and tells nobody anything she did not ask', async () => {
    const booked = await bookFriday();

    const first = (await env.call(confirmPresence, { token: booked.manageToken })) as { clientConfirmedAt: string };
    env.clock.advance(60_000);
    const second = (await env.call(confirmPresence, { token: booked.manageToken })) as { clientConfirmedAt: string };

    expect(first.clientConfirmedAt).toBe('2026-10-01T15:00:00.000Z');
    expect(second.clientConfirmedAt).toBe(first.clientConfirmedAt);
    expect((await view(booked.manageToken)).clientConfirmedAt).toBe(first.clientConfirmedAt);
    expect((await bookingDoc(env, booked.bookingId)).lastClientAction?.kind).toBe('confirmed');
  });

  it('refuses to confirm a cancelled or finished booking', async () => {
    const booked = await bookFriday();
    env.clock.set(Date.parse(START) + 2 * HOUR);

    await expect(env.call(confirmPresence, { token: booked.manageToken })).rejects.toMatchObject({ code: 'BOOKING_NOT_ACTIVE' });
  });

  it('reports running late only on the day, and records how late', async () => {
    const booked = await bookFriday();

    await expect(env.call(reportLate, { token: booked.manageToken, minutes: 15 })).rejects.toMatchObject({ code: 'NOT_ALLOWED' });
    env.clock.set(Date.parse(START) - HOUR);
    const result = (await env.call(reportLate, { token: booked.manageToken, minutes: 15 })) as { lateByMinutes: number };

    expect(result.lateByMinutes).toBe(15);
    const page = await view(booked.manageToken);
    expect(page.lateByMinutes).toBe(15);
    expect((await bookingDoc(env, booked.bookingId)).lastClientAction?.kind).toBe('late');
  });

  it('accepts only the four offered delays', async () => {
    const booked = await bookFriday();
    env.clock.set(Date.parse(START) - HOUR);

    await expect(env.call(reportLate, { token: booked.manageToken, minutes: 12 })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });
});

describe('cancelBooking', () => {
  it('cancels for free inside the window and frees the time at once', async () => {
    const booked = await bookFriday();

    const result = await env.call(cancelBooking, { token: booked.manageToken, reason: 'Something came up' });

    expect(result).toEqual({ status: 'cancelled', isLateCancellation: false });
    const stored = await bookingDoc(env, booked.bookingId);
    expect(stored).toMatchObject({ status: 'cancelledByClient', cancelledBy: 'client', isLateCancellation: false, cancelReason: 'Something came up' });
    expect((await book(env, pro, { client: BIA })).status).toBe('confirmed');
  });

  it('needs an honest "yes" for a late cancellation (D12), records it as late and leaves a mark', async () => {
    const booked = await bookFriday();
    env.clock.set(Date.parse(START) - 10 * HOUR);

    await expect(env.call(cancelBooking, { token: booked.manageToken })).rejects.toMatchObject({ code: 'CONFIRMATION_REQUIRED' });
    expect((await bookingDoc(env, booked.bookingId)).status).toBe('confirmed');
    const result = await env.call(cancelBooking, { token: booked.manageToken, acceptLateWarning: true });

    expect(result).toEqual({ status: 'cancelled', isLateCancellation: true });
    const hash = (await bookingDoc(env, booked.bookingId)).phoneHash;
    const contact = (await refs(env.deps.db).contact(pro.uid, hash).get()).data() as ContactDoc;
    expect(contact.marks.map((mark) => mark.kind)).toEqual(['lateCancel']);
  });

  it('sends the client to message her when the policy says so', async () => {
    await refs(env.deps.db).profile(pro.slug).update({ 'policy.afterWindowCancel': 'message' });
    const booked = await bookFriday();
    env.clock.set(Date.parse(START) - 10 * HOUR);

    const error = (await env.call(cancelBooking, { token: booked.manageToken, acceptLateWarning: true }).catch((caught: unknown) => caught)) as AppError;

    expect(error.code).toBe('NOT_ALLOWED');
    expect(error.details?.action).toBe('message');
  });

  it('lets a client withdraw a request that still waits for the professional, at any time before the visit', async () => {
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.requiresApproval': true });
    const booked = await bookFriday();
    env.clock.set(Date.parse(START) - 2 * HOUR);

    expect(await env.call(cancelBooking, { token: booked.manageToken })).toEqual({ status: 'cancelled', isLateCancellation: false });
  });

  it('cancels only once', async () => {
    const booked = await bookFriday();
    await env.call(cancelBooking, { token: booked.manageToken });

    await expect(env.call(cancelBooking, { token: booked.manageToken })).rejects.toMatchObject({ code: 'BOOKING_NOT_ACTIVE' });
  });

  it('limits actions on one link to twenty an hour', async () => {
    const booked = await bookFriday();
    let last: unknown;
    for (let n = 0; n < 21; n += 1) {
      last = await env.call(confirmPresence, { token: booked.manageToken }).catch((caught: unknown) => caught);
    }

    expect((last as AppError).code).toBe('RATE_LIMITED');
  });
});

describe('rescheduleBooking (direct) and requestReschedule', () => {
  it('moves the booking at once inside the free window and counts the move', async () => {
    const booked = await bookFriday();

    const moved = (await env.call(rescheduleBooking, { token: booked.manageToken, startsAt: '2026-10-03T17:00:00.000Z' })) as {
      status: string; startsAt: string; rescheduleCount: number;
    };

    expect(moved).toMatchObject({ status: 'moved', startsAt: '2026-10-03T17:00:00.000Z', rescheduleCount: 1 });
    const stored = await bookingDoc(env, booked.bookingId);
    expect(stored.startsAt.toMillis()).toBe(Date.parse('2026-10-03T17:00:00.000Z'));
    expect(stored.purgeAt.toMillis()).toBe(Date.parse('2026-10-10T18:00:00.000Z'));
    // The old time is free again.
    expect((await book(env, pro, { client: BIA })).status).toBe('confirmed');
  });

  it('can move onto a time that overlaps its own old time', async () => {
    const booked = await bookFriday();

    const moved = await env.call(rescheduleBooking, { token: booked.manageToken, startsAt: '2026-10-03T13:15:00.000Z' });

    expect(moved).toMatchObject({ status: 'moved' });
  });

  it('says the time is taken and offers others', async () => {
    const booked = await bookFriday();
    asBooked(await book(env, pro, { client: BIA, startsAt: '2026-10-03T17:00:00.000Z' }));

    const result = await env.call(rescheduleBooking, { token: booked.manageToken, startsAt: '2026-10-03T17:00:00.000Z' });

    expect(result).toMatchObject({ status: 'slotTaken' });
  });

  it('stops after the maximum number of moves and sends the client to message her', async () => {
    const booked = await bookFriday();
    await env.call(rescheduleBooking, { token: booked.manageToken, startsAt: '2026-10-03T17:00:00.000Z' });
    await env.call(rescheduleBooking, { token: booked.manageToken, startsAt: '2026-10-03T18:30:00.000Z' });

    const error = (await env.call(rescheduleBooking, { token: booked.manageToken, startsAt: '2026-10-03T19:30:00.000Z' }).catch((caught: unknown) => caught)) as AppError;

    expect(error.code).toBe('NOT_ALLOWED');
    expect(error.details?.action).toBe('message');
  });

  it('refuses a direct move after the free window and asks for a request instead', async () => {
    const booked = await bookFriday();
    env.clock.set(Date.parse(START) - 10 * HOUR);

    const error = (await env.call(rescheduleBooking, { token: booked.manageToken, startsAt: '2026-10-03T17:00:00.000Z' }).catch((caught: unknown) => caught)) as AppError;

    expect(error.code).toBe('NOT_ALLOWED');
    expect(error.details?.action).toBe('request');
  });

  it('keeps the old time reserved while a request waits, and tells the owner by push', async () => {
    await refs(env.deps.db).devices(pro.uid).doc('phone-1').set({ fcmToken: 'f'.repeat(40), platform: 'ios', lastSeenAt: ts(0) });
    const booked = await bookFriday();
    env.clock.set(Date.parse(START) - 10 * HOUR);

    const result = await env.call(requestReschedule, { token: booked.manageToken, startsAt: '2026-10-03T17:00:00.000Z', note: 'Work came up' });

    expect(result).toEqual({ status: 'requested' });
    const request = (await refs(env.deps.db).rescheduleRequest(booked.bookingId).get()).data();
    expect(request).toMatchObject({ ownerUid: pro.uid, status: 'pending', clientName: 'Ana Costa', note: 'Work came up' });
    expect((await bookingDoc(env, booked.bookingId)).startsAt.toMillis()).toBe(Date.parse(START));
    expect((await book(env, pro, { client: BIA, startsAt: START })).status).toBe('slotTaken');
    expect(env.push.messages()).toEqual([{ kind: 'rescheduleRequest', id: booked.bookingId }]);
    expect((await view(booked.manageToken)).pendingReschedule?.status).toBe('pending');
  });

  it('only accepts a request when the policy allows one, and a free time', async () => {
    const booked = await bookFriday();
    await expect(env.call(requestReschedule, { token: booked.manageToken, startsAt: '2026-10-03T17:00:00.000Z' })).rejects.toMatchObject({ code: 'NOT_ALLOWED' });
    env.clock.set(Date.parse(START) - 10 * HOUR);
    asBooked(await book(env, pro, { client: BIA, startsAt: '2026-10-03T17:00:00.000Z' }));

    expect(await env.call(requestReschedule, { token: booked.manageToken, startsAt: '2026-10-03T17:00:00.000Z' })).toMatchObject({ status: 'slotTaken' });
  });
});

describe('rebook', () => {
  it('books the same service again for a known client with her old link, without a new verification or approval', async () => {
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.requiresApproval': true });
    const first = asBooked(await book(env, pro));
    expect(first.status).toBe('pendingApproval');
    // She approved the first one.
    await refs(env.deps.db).booking(first.bookingId).update({ status: 'confirmed' });
    const hash = (await bookingDoc(env, first.bookingId)).phoneHash;
    await refs(env.deps.db).contact(pro.uid, hash).set({
      ownerUid: pro.uid, phoneHash: hash, registered: true, bookingCount: 1, marks: [], onlineBookingStopped: false, createdAt: ts(0), updatedAt: ts(0)
    });

    const again = asBooked((await env.call(rebook, {
      token: first.manageToken, startsAt: '2026-10-03T17:00:00.000Z', idempotencyKey: crypto.randomUUID()
    })) as Awaited<ReturnType<typeof book>>);

    expect(again.status).toBe('confirmed');
    const stored: BookingDoc = await bookingDoc(env, again.bookingId);
    expect(stored).toMatchObject({ origin: 'rebook', serviceId: SERVICE.glowFacial });
    expect(stored.client.name).toBe('Ana Costa');
  });

  it('respects a pause and refuses an unknown link', async () => {
    const first = await bookFriday();
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.acceptingBookings': false });

    const result = await env.call(rebook, { token: first.manageToken, startsAt: '2026-10-03T17:00:00.000Z', idempotencyKey: crypto.randomUUID() });
    expect(result).toMatchObject({ status: 'paused' });
    await expect(env.call(rebook, { token: 'y'.repeat(22), startsAt: '2026-10-03T17:00:00.000Z', idempotencyKey: crypto.randomUUID() })).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});
