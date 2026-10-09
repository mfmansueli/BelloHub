import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import type { ContactDoc } from '../../src/lib/docs.js';
import { phoneHashOf } from '../../src/lib/emailProof.js';
import { refs, ts } from '../../src/lib/store.js';
import { cancelBookingByOwner } from '../../src/owner/cancelBookingByOwner.js';
import { markNoShow } from '../../src/owner/markNoShow.js';
import { moveBookingByOwner } from '../../src/owner/moveBookingByOwner.js';
import { offerWaitlistSlot } from '../../src/owner/offerWaitlistSlot.js';
import { removeWaitlistEntry } from '../../src/owner/removeWaitlistEntry.js';
import { respondBookingRequest } from '../../src/owner/respondBookingRequest.js';
import { respondRescheduleRequest } from '../../src/owner/respondRescheduleRequest.js';
import { setOnlineBookingStopped } from '../../src/owner/setOnlineBookingStopped.js';
import { getHold } from '../../src/public/getHold.js';
import { joinWaitlist } from '../../src/public/joinWaitlist.js';
import { requestReschedule } from '../../src/token/requestReschedule.js';
import { ANA, asBooked, BIA, book, bookingDoc, type Outcome } from '../support/booking.js';
import { createTestEnv, PEPPER, resetEmulators } from '../support/env.js';
import { captureWorld, ownerContext, restoreWorld, SERVICE, seedProfessional } from '../support/seed.js';
import type { Professional, World } from '../support/seed.js';

const env = createTestEnv();
let pro: Professional;
let world: World;
const HOUR = 3_600_000;
/** Saturday 2026-10-03 10:00 in Sao Paulo. */
const START = '2026-10-03T13:00:00.000Z';
const LATER = '2026-10-03T17:00:00.000Z';

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

const owner = () => ownerContext(pro.uid);

async function pending(client = ANA, startsAt = START) {
  await refs(env.deps.db).profile(pro.slug).update({ 'booking.requiresApproval': true });
  const request = asBooked(await book(env, pro, { client: { ...client, email: 'ana@example.com' }, startsAt }));
  env.mail.sent.length = 0; // the "request received" email is not what these tests are about
  return request;
}

async function registrations(): Promise<number> {
  return ((await refs(env.deps.db).account(pro.uid).get()).data() as { registrations: { count: number } }).registrations.count;
}

describe('respondBookingRequest (D42: approving is what adds the client)', () => {
  it('approves a request, registers the new client and tells her by email', async () => {
    const request = await pending();

    const result = await env.call(respondBookingRequest, { bookingId: request.bookingId, decision: 'approve' }, owner());

    expect(result).toEqual({ status: 'confirmed' });
    const stored = await bookingDoc(env, request.bookingId);
    expect(stored.status).toBe('confirmed');
    expect(stored.pendingReason).toBeUndefined();
    expect(await registrations()).toBe(1);
    expect(env.mail.sent).toHaveLength(1);
    expect(env.mail.sent[0]?.subject).toContain('Maria Souza');
  });

  it('shows the paywall (needsSubscription) instead of approving a new client past the free registrations, and keeps the request', async () => {
    const request = await pending();
    await refs(env.deps.db).account(pro.uid).update({ 'registrations.count': 10 });

    const result = await env.call(respondBookingRequest, { bookingId: request.bookingId, decision: 'approve' }, owner());

    expect(result).toEqual({ status: 'needsSubscription' });
    expect((await bookingDoc(env, request.bookingId)).status).toBe('pendingApproval');
    expect(await registrations()).toBe(10);
    expect(env.mail.sent).toHaveLength(0);

    // She subscribes: the plan is mirrored, and approving now works.
    await refs(env.deps.db).account(pro.uid).update({ plan: { state: 'active', expiresAt: ts(env.clock.now() + 30 * 24 * HOUR), source: 'appStore' } });
    expect(await env.call(respondBookingRequest, { bookingId: request.bookingId, decision: 'approve' }, owner())).toEqual({ status: 'confirmed' });
    expect(await registrations()).toBe(11);
  });

  it('approves a returning client without counting her again', async () => {
    const first = await pending();
    await env.call(respondBookingRequest, { bookingId: first.bookingId, decision: 'approve' }, owner());
    await refs(env.deps.db).account(pro.uid).update({ 'registrations.count': 10 });
    await refs(env.deps.db).profile(pro.slug).update({ 'booking.requiresApproval': false });
    await refs(env.deps.db).availability(pro.uid).update({ 'noShow.isOn': true, 'noShow.action': 'approveNewBookings' });
    const hash = phoneHashOf(PEPPER, ANA.phone);
    await refs(env.deps.db).contact(pro.uid, hash).update({
      marks: [1, 2, 3].map((n) => ({ id: `m${n}`, at: ts(env.clock.now() - n * 24 * HOUR), kind: 'noShow' }))
    });
    const second = asBooked(await book(env, pro, { startsAt: LATER }));
    expect(second.status).toBe('pendingApproval');

    expect(await env.call(respondBookingRequest, { bookingId: second.bookingId, decision: 'approve' }, owner())).toEqual({ status: 'confirmed' });
    expect(await registrations()).toBe(10);
  });

  it('declines a request, frees the time and emails the client without a booking link', async () => {
    const request = await pending();

    const result = await env.call(respondBookingRequest, { bookingId: request.bookingId, decision: 'decline' }, owner());

    expect(result).toEqual({ status: 'declined' });
    expect((await bookingDoc(env, request.bookingId)).status).toBe('declined');
    expect(await registrations()).toBe(0);
    expect(env.mail.sent[0]?.text).not.toContain('/m/');
    expect(env.mail.sent[0]?.text).toContain('https://bellohub.test/maria');
    expect((await book(env, pro, { client: BIA, startsAt: START })).status).toBe('pendingApproval');
  });

  it('answers only for pending requests of her own', async () => {
    const request = await pending();
    const stranger = ownerContext('someone-else');

    await expect(env.call(respondBookingRequest, { bookingId: request.bookingId, decision: 'approve' }, stranger)).rejects.toMatchObject({ code: 'NOT_FOUND' });
    await env.call(respondBookingRequest, { bookingId: request.bookingId, decision: 'approve' }, owner());
    await expect(env.call(respondBookingRequest, { bookingId: request.bookingId, decision: 'approve' }, owner())).rejects.toMatchObject({ code: 'BOOKING_NOT_ACTIVE' });
  });

  it('needs a signed-in professional', async () => {
    const request = await pending();

    await expect(env.call(respondBookingRequest, { bookingId: request.bookingId, decision: 'approve' })).rejects.toMatchObject({ code: 'UNAUTHENTICATED' });
  });
});

describe('cancelBookingByOwner and moveBookingByOwner', () => {
  it('cancels without counting against the client, frees the time and emails her', async () => {
    const booked = asBooked(await book(env, pro, { client: { ...ANA, email: 'ana@example.com' }, startsAt: START }));
    env.mail.sent.length = 0;
    env.clock.set(Date.parse(START) - 2 * HOUR);

    const result = await env.call(cancelBookingByOwner, { bookingId: booked.bookingId, reason: 'I am unwell' }, owner());

    expect(result).toEqual({ status: 'cancelled' });
    const stored = await bookingDoc(env, booked.bookingId);
    expect(stored).toMatchObject({ status: 'cancelledByPro', cancelledBy: 'professional', isLateCancellation: false });
    const contact = (await refs(env.deps.db).contact(pro.uid, stored.phoneHash).get()).data() as ContactDoc;
    expect(contact.marks).toEqual([]);
    expect(env.mail.sent[0]?.subject).toMatch(/cancelado|cancelled/i);
    await expect(env.call(cancelBookingByOwner, { bookingId: booked.bookingId }, owner())).rejects.toMatchObject({ code: 'BOOKING_NOT_ACTIVE' });
  });

  it('moves a booking to a new time without checking her own hours, and updates the retention date', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));

    const result = await env.call(moveBookingByOwner, { bookingId: booked.bookingId, startsAt: '2026-10-04T13:00:00.000Z' }, owner()); // a Sunday

    expect(result).toEqual({ startsAt: '2026-10-04T13:00:00.000Z', endsAt: '2026-10-04T14:00:00.000Z' });
    const stored = await bookingDoc(env, booked.bookingId);
    expect(stored.purgeAt.toMillis()).toBe(Date.parse('2026-10-11T14:00:00.000Z'));
    expect(stored.clientConfirmedAt).toBeUndefined();
  });

  it('cannot touch another professional\'s booking', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));

    await expect(env.call(moveBookingByOwner, { bookingId: booked.bookingId, startsAt: LATER }, ownerContext('someone-else'))).rejects.toMatchObject({ code: 'NOT_FOUND' });
    await expect(env.call(cancelBookingByOwner, { bookingId: booked.bookingId }, ownerContext('someone-else'))).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('respondRescheduleRequest', () => {
  async function requested() {
    const booked = asBooked(await book(env, pro, { client: { ...ANA, email: 'ana@example.com' }, startsAt: START }));
    env.clock.set(Date.parse(START) - 10 * HOUR);
    await env.call(requestReschedule, { token: booked.manageToken, startsAt: LATER, note: 'Sorry for the short notice' });
    env.mail.sent.length = 0;
    return booked;
  }

  it('accepts: the booking moves, counts as a move and the client is told', async () => {
    const booked = await requested();

    const result = await env.call(respondRescheduleRequest, { requestId: booked.bookingId, decision: 'accept' }, owner());

    expect(result).toEqual({ status: 'accepted' });
    const stored = await bookingDoc(env, booked.bookingId);
    expect(stored.startsAt.toMillis()).toBe(Date.parse(LATER));
    expect(stored.rescheduleCount).toBe(1);
    expect((await refs(env.deps.db).rescheduleRequest(booked.bookingId).get()).data()).toMatchObject({ status: 'accepted' });
    expect(env.mail.sent).toHaveLength(1);
  });

  it('says the time is taken when it was booked meanwhile and leaves the request open', async () => {
    const booked = await requested();
    asBooked(await book(env, pro, { client: BIA, startsAt: LATER }));

    const result = await env.call(respondRescheduleRequest, { requestId: booked.bookingId, decision: 'accept' }, owner());

    expect(result).toEqual({ status: 'slotTaken' });
    expect((await bookingDoc(env, booked.bookingId)).startsAt.toMillis()).toBe(Date.parse(START));
    expect((await refs(env.deps.db).rescheduleRequest(booked.bookingId).get()).data()).toMatchObject({ status: 'pending' });
  });

  it('declines: the booking stays where it was', async () => {
    const booked = await requested();

    expect(await env.call(respondRescheduleRequest, { requestId: booked.bookingId, decision: 'decline' }, owner())).toEqual({ status: 'declined' });
    expect((await bookingDoc(env, booked.bookingId)).startsAt.toMillis()).toBe(Date.parse(START));
    await expect(env.call(respondRescheduleRequest, { requestId: booked.bookingId, decision: 'accept' }, owner())).rejects.toMatchObject({ code: 'BOOKING_NOT_ACTIVE' });
  });

  it('belongs to its professional', async () => {
    const booked = await requested();

    await expect(env.call(respondRescheduleRequest, { requestId: booked.bookingId, decision: 'accept' }, ownerContext('someone-else'))).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('waitlist', () => {
  const join = (overrides: Record<string, unknown> = {}, ip = '203.0.113.9') =>
    env.call(joinWaitlist, {
      slug: pro.slug, name: 'Paula Nunes', phone: '+5511955550000', locale: 'pt-BR', dayFrom: '2026-10-03', dayTo: '2026-10-09', ...overrides
    }, { ip });

  it('records a person who waits, once for the same range, and tells the owner generically', async () => {
    await refs(env.deps.db).devices(pro.uid).doc('phone-1').set({ fcmToken: 'f'.repeat(40), platform: 'ios', lastSeenAt: ts(0) });

    await join({ serviceId: SERVICE.glowFacial });
    await join({ serviceId: SERVICE.glowFacial }, '203.0.113.10');

    const entries = await refs(env.deps.db).waitlist().get();
    expect(entries.size).toBe(1);
    expect(entries.docs[0]?.data()).toMatchObject({ ownerUid: pro.uid, status: 'waiting', serviceName: 'Glow Facial' });
    expect(env.push.messages()).toHaveLength(1);
    expect(env.push.messages()[0]?.kind).toBe('waitlist');
  });

  it('rejects a range that runs backwards, one in the past and one that is too long', async () => {
    await expect(join({ dayFrom: '2026-10-09', dayTo: '2026-10-03' })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(join({ dayFrom: '2026-09-01', dayTo: '2026-09-05' })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(join({ dayFrom: '2026-10-03', dayTo: '2026-12-31' })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('limits one phone to three entries a day', async () => {
    await join({ dayTo: '2026-10-05' });
    await join({ dayTo: '2026-10-06' }, '203.0.113.10');
    await join({ dayTo: '2026-10-07' }, '203.0.113.11');

    await expect(join({ dayTo: '2026-10-08' }, '203.0.113.12')).rejects.toMatchObject({ code: 'RATE_LIMITED' });
  });

  it('offers a freed time: holds it for that person and opens with the one-time key, then marks the entry booked', async () => {
    await join();
    const entry = (await refs(env.deps.db).waitlist().get()).docs[0];
    const waitlistId = entry?.id ?? '';

    const offer = (await env.call(offerWaitlistSlot, { waitlistId, serviceId: SERVICE.glowFacial, startsAt: START }, owner())) as { status: string; holdKey: string; expiresAt: string };

    expect(offer.status).toBe('offered');
    expect(offer.expiresAt).toBe('2026-10-01T18:00:00.000Z'); // 3 hours by default
    expect((await refs(env.deps.db).waitlistEntry(waitlistId).get()).data()).toMatchObject({ status: 'offered' });
    expect(await env.call(getHold, { slug: pro.slug, holdKey: offer.holdKey })).toMatchObject({ startsAt: START });
    expect((await book(env, pro, { client: BIA, startsAt: START })).status).toBe('slotTaken');

    const booked = asBooked(await book(env, pro, { client: { name: 'Paula Nunes', phone: '+5511955550000', email: undefined }, startsAt: START, holdKey: offer.holdKey }));
    expect(booked.status).toBe('confirmed');
    expect((await bookingDoc(env, booked.bookingId)).origin).toBe('waitlist');
    expect((await refs(env.deps.db).waitlistEntry(waitlistId).get()).data()).toMatchObject({ status: 'booked' });
  });

  it('will not offer a time that is not free, and not somebody else\'s entry', async () => {
    await join();
    const waitlistId = (await refs(env.deps.db).waitlist().get()).docs[0]?.id ?? '';
    asBooked(await book(env, pro, { startsAt: START }));

    expect(await env.call(offerWaitlistSlot, { waitlistId, serviceId: SERVICE.glowFacial, startsAt: START }, owner())).toEqual({ status: 'slotTaken' });
    await expect(env.call(offerWaitlistSlot, { waitlistId, serviceId: SERVICE.glowFacial, startsAt: LATER }, ownerContext('someone-else'))).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('removes an entry, but only her own', async () => {
    await join();
    const waitlistId = (await refs(env.deps.db).waitlist().get()).docs[0]?.id ?? '';

    await env.call(removeWaitlistEntry, { waitlistId }, ownerContext('someone-else'));
    expect((await refs(env.deps.db).waitlist().get()).size).toBe(1);
    await env.call(removeWaitlistEntry, { waitlistId }, owner());
    expect((await refs(env.deps.db).waitlist().get()).size).toBe(0);
  });
});

describe('markNoShow and setOnlineBookingStopped (D13)', () => {
  const mark = (extra: Record<string, unknown>) => env.call(markNoShow, { phone: ANA.phone, ...extra }, owner());

  it('counts marks idempotently and forgives one', async () => {
    const id1 = crypto.randomUUID();
    await mark({ action: 'mark', markId: id1 });
    await mark({ action: 'mark', markId: id1 });
    expect(await mark({ action: 'mark', markId: crypto.randomUUID() })).toEqual({ counted: 2 });

    expect(await mark({ action: 'forgive', markId: id1 })).toEqual({ counted: 1 });
  });

  it('starts the count from zero and ignores marks older than the counting months', async () => {
    await mark({ action: 'mark', markId: crypto.randomUUID() });
    await mark({ action: 'mark', markId: crypto.randomUUID(), markedAt: '2024-01-01T10:00:00.000Z' });
    expect(await mark({ action: 'mark', markId: crypto.randomUUID() })).toEqual({ counted: 2 });

    expect(await mark({ action: 'reset' })).toEqual({ counted: 0 });
    env.clock.advance(1000);
    expect(await mark({ action: 'mark', markId: crypto.randomUUID() })).toEqual({ counted: 1 });
  });

  it('marks the booking as a no-show when the app sends its id', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));

    await mark({ action: 'mark', markId: crypto.randomUUID(), bookingId: booked.bookingId });

    expect((await bookingDoc(env, booked.bookingId)).status).toBe('noShow');
  });

  it('needs a mark id to mark or forgive', async () => {
    await expect(mark({ action: 'mark' })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('sets and clears the online booking stop for a phone', async () => {
    await env.call(setOnlineBookingStopped, { phone: ANA.phone, stopped: true }, owner());
    expect((await book(env, pro, { startsAt: START })).status).toBe('paused');

    await env.call(setOnlineBookingStopped, { phone: ANA.phone, stopped: false }, owner());
    expect((await book(env, pro, { startsAt: START })).status).toBe('confirmed');
  });

  it('keeps one professional\'s marks away from another\'s', async () => {
    const other = await seedProfessional(env, { uid: 'pro-other', slug: 'other-pro' });
    await mark({ action: 'mark', markId: crypto.randomUUID() });
    await mark({ action: 'mark', markId: crypto.randomUUID() });
    await mark({ action: 'mark', markId: crypto.randomUUID() });

    const outcome: Outcome = await book(env, other, { slug: other.slug, startsAt: START });
    expect(outcome.status).toBe('confirmed');
  });
});
