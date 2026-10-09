import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { handleAppStoreNotification } from '../../src/http/appStoreHandler.js';
import type { AccountDoc, BookingDoc } from '../../src/lib/docs.js';
import { refs, ts } from '../../src/lib/store.js';
import { UnconfiguredAppStoreVerifier } from '../../src/billing/UnconfiguredAppStoreVerifier.js';
import { AppError } from '../../src/lib/errors.js';
import { ensureAccount } from '../../src/owner/ensureAccount.js';
import { syncPlan } from '../../src/owner/syncPlan.js';
import { joinWaitlist } from '../../src/public/joinWaitlist.js';
import { cancelBooking } from '../../src/token/cancelBooking.js';
import { confirmPresence } from '../../src/token/confirmPresence.js';
import { reportLate } from '../../src/token/reportLate.js';
import { rescheduleBooking } from '../../src/token/rescheduleBooking.js';
import { handleBookingWritten } from '../../src/triggers/handleBookingWritten.js';
import { asBooked, book, bookingDoc } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { captureWorld, ownerContext, restoreWorld, seedProfessional } from '../support/seed.js';
import type { Professional, World } from '../support/seed.js';

const env = createTestEnv();
let pro: Professional;
let world: World;
const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const START = '2026-10-03T13:00:00.000Z';

beforeAll(async () => {
  await resetEmulators(env);
  pro = await seedProfessional(env);
  world = await captureWorld(env, pro);
});

beforeEach(async () => {
  await resetEmulators(env);
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  env.push.calls.length = 0;
  env.push.invalidIds.clear();
  await restoreWorld(env, world);
  await refs(env.deps.db).devices(pro.uid).doc('phone-1').set({ fcmToken: 'f'.repeat(40), platform: 'ios', lastSeenAt: ts(0) });
  await refs(env.deps.db).devices(pro.uid).doc('phone-2').set({ fcmToken: 'g'.repeat(40), platform: 'ios', lastSeenAt: ts(0) });
});

/** Replays what the Firestore trigger would deliver for a change of one booking. */
async function trigger(bookingId: string, before: BookingDoc | undefined) {
  await handleBookingWritten(env.deps, bookingId, before, await bookingDoc(env, bookingId));
}

describe('onBookingWritten: generic pushes to the professional', () => {
  it('pushes a kind and an id for a new booking, to every device, and nothing else', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));

    await trigger(booked.bookingId, undefined);

    expect(env.push.calls).toHaveLength(1);
    expect(env.push.calls[0]?.targets).toHaveLength(2);
    expect(env.push.calls[0]?.message).toEqual({ kind: 'booking', id: booked.bookingId });
    expect(JSON.stringify(env.push.calls)).not.toContain('Ana');
    expect(JSON.stringify(env.push.calls)).not.toContain('Glow');
  });

  it('pushes when the client confirms, runs late, reschedules or cancels, but not when nothing the client did changed', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));
    let before = await bookingDoc(env, booked.bookingId);

    await env.call(confirmPresence, { token: booked.manageToken });
    await trigger(booked.bookingId, before);
    before = await bookingDoc(env, booked.bookingId);
    await env.call(rescheduleBooking, { token: booked.manageToken, startsAt: '2026-10-03T17:00:00.000Z' });
    await trigger(booked.bookingId, before);
    before = await bookingDoc(env, booked.bookingId);
    env.clock.set(Date.parse('2026-10-03T17:00:00.000Z') - HOUR);
    await env.call(reportLate, { token: booked.manageToken, minutes: 10 });
    await trigger(booked.bookingId, before);
    before = await bookingDoc(env, booked.bookingId);
    // The professional's own edit: no client action changed.
    await refs(env.deps.db).booking(booked.bookingId).update({ cancelReason: 'x', updatedAt: ts(env.clock.now()) });
    await trigger(booked.bookingId, before);
    before = await bookingDoc(env, booked.bookingId);
    await env.call(cancelBooking, { token: booked.manageToken, acceptLateWarning: true });
    await trigger(booked.bookingId, before);

    expect(env.push.messages().map((message) => message.kind)).toEqual(['bookingConfirmed', 'booking', 'bookingLate', 'booking']);
  });

  it('pushes about the waitlist when a cancellation frees a time somebody waits for', async () => {
    await env.call(joinWaitlist, { slug: pro.slug, name: 'Paula', phone: '+5511955550000', locale: 'pt-BR', dayFrom: '2026-10-03', dayTo: '2026-10-05' });
    env.push.calls.length = 0;
    const booked = asBooked(await book(env, pro, { startsAt: START }));
    const before = await bookingDoc(env, booked.bookingId);
    await env.call(cancelBooking, { token: booked.manageToken });

    await trigger(booked.bookingId, before);

    expect(env.push.messages().map((message) => message.kind)).toEqual(['booking', 'waitlist']);
  });

  it('does not push about the waitlist when nobody waits, or for another day, or for a service that does not fit', async () => {
    await env.call(joinWaitlist, { slug: pro.slug, name: 'Paula', phone: '+5511955550000', locale: 'pt-BR', dayFrom: '2026-10-06', dayTo: '2026-10-07' });
    env.push.calls.length = 0; // joining the list pushed once; this test is about the cancellation
    const booked = asBooked(await book(env, pro, { startsAt: START }));
    const before = await bookingDoc(env, booked.bookingId);
    await env.call(cancelBooking, { token: booked.manageToken });

    await trigger(booked.bookingId, before);

    expect(env.push.messages().map((message) => message.kind)).toEqual(['booking']);
  });

  it('pushes nothing when the professional has no device, and removes a token FCM says is gone', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: START }));
    env.push.invalidIds.add('phone-2');

    await trigger(booked.bookingId, undefined);

    expect((await refs(env.deps.db).devices(pro.uid).get()).docs.map((doc) => doc.id)).toEqual(['phone-1']);
    await refs(env.deps.db).devices(pro.uid).doc('phone-1').delete();
    env.push.calls.length = 0;
    await trigger(booked.bookingId, undefined);
    expect(env.push.calls).toHaveLength(0);
  });

  it('does nothing when the booking was deleted', async () => {
    await handleBookingWritten(env.deps, 'gone', undefined, undefined);

    expect(env.push.calls).toHaveLength(0);
  });
});

describe('syncPlan (purchases are re-verified on the server, D33)', () => {
  const signed = 'signed-transaction-jws-0123456789';

  async function token(): Promise<string> {
    return ((await env.call(ensureAccount, { countryCode: 'BR', locale: 'pt-BR' }, ownerContext(pro.uid))) as { appAccountToken: string }).appAccountToken;
  }

  async function plan(): Promise<AccountDoc['plan']> {
    return ((await refs(env.deps.db).account(pro.uid).get()).data() as AccountDoc).plan;
  }

  it('unlocks the plan for a verified purchase made for this account, until it expires', async () => {
    env.appStore.addTransaction(signed, {
      productId: 'com.bellohub.pro.monthly', bundleId: 'com.bellohub', environment: 'Production',
      appAccountToken: (await token()).toUpperCase(), expiresAt: env.clock.now() + 30 * DAY
    });

    const result = await env.call(syncPlan, { signedTransaction: signed }, ownerContext(pro.uid));

    expect(result).toEqual({ plan: { state: 'active', expiresAt: new Date(env.clock.now() + 30 * DAY).toISOString() } });
    expect((await plan()).state).toBe('active');
  });

  it('refuses a purchase made for another account, another product, or one it cannot verify', async () => {
    await token();
    env.appStore.addTransaction('other-account-jws-0123456789', {
      productId: 'com.bellohub.pro.yearly', bundleId: 'com.bellohub', environment: 'Production', appAccountToken: crypto.randomUUID(), expiresAt: env.clock.now() + DAY
    });
    env.appStore.addTransaction('other-product-jws-0123456789', {
      productId: 'com.example.coins', bundleId: 'com.bellohub', environment: 'Production', appAccountToken: await token(), expiresAt: env.clock.now() + DAY
    });

    await expect(env.call(syncPlan, { signedTransaction: 'other-account-jws-0123456789' }, ownerContext(pro.uid))).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
    await expect(env.call(syncPlan, { signedTransaction: 'other-product-jws-0123456789' }, ownerContext(pro.uid))).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
    await expect(env.call(syncPlan, { signedTransaction: 'forged-jws-0123456789abcdef' }, ownerContext(pro.uid))).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
    expect((await plan()).state).toBe('none');
  });

  it('does not lower a plan that runs longer when an older receipt arrives, but a revoke always applies', async () => {
    const appAccountToken = await token();
    env.appStore.addTransaction(signed, { productId: 'com.bellohub.pro.yearly', bundleId: 'com.bellohub', environment: 'Production', appAccountToken, expiresAt: env.clock.now() + 300 * DAY });
    await env.call(syncPlan, { signedTransaction: signed }, ownerContext(pro.uid));
    env.appStore.addTransaction('older-jws-0123456789abcdef', { productId: 'com.bellohub.pro.monthly', bundleId: 'com.bellohub', environment: 'Production', appAccountToken, expiresAt: env.clock.now() + 5 * DAY });
    env.appStore.addTransaction('refund-jws-0123456789abcdef', { productId: 'com.bellohub.pro.yearly', bundleId: 'com.bellohub', environment: 'Production', appAccountToken, expiresAt: env.clock.now() + 300 * DAY, revokedAt: env.clock.now() - 1 });

    const stale = (await env.call(syncPlan, { signedTransaction: 'older-jws-0123456789abcdef' }, ownerContext(pro.uid))) as { plan: { state: string } };
    expect(stale.plan.state).toBe('active');
    expect((await plan()).expiresAt?.toMillis()).toBe(env.clock.now() + 300 * DAY);

    const refunded = (await env.call(syncPlan, { signedTransaction: 'refund-jws-0123456789abcdef' }, ownerContext(pro.uid))) as { plan: { state: string } };
    expect(refunded.plan.state).toBe('revoked');
  });

  it('answers NOT_CONFIGURED until a human installs the Apple settings, and leaves the plan alone', async () => {
    const original = env.deps.appStore;
    env.deps.appStore = new UnconfiguredAppStoreVerifier();
    try {
      await expect(env.call(syncPlan, { signedTransaction: signed }, ownerContext(pro.uid))).rejects.toMatchObject({ code: 'NOT_CONFIGURED' });
    } finally {
      env.deps.appStore = original;
    }
    expect((await plan()).state).toBe('none');
  });
});

describe('appStoreNotifications', () => {
  async function accountToken(): Promise<string> {
    return ((await env.call(ensureAccount, { countryCode: 'BR', locale: 'pt-BR' }, ownerContext(pro.uid))) as { appAccountToken: string }).appAccountToken;
  }

  it('mirrors a renewal into the account plan', async () => {
    env.appStore.addNotification('notification-jws-0123456789', {
      type: 'DID_RENEW',
      transaction: { productId: 'com.bellohub.pro.yearly', bundleId: 'com.bellohub', environment: 'Production', appAccountToken: await accountToken(), expiresAt: env.clock.now() + 365 * DAY }
    });

    expect(await handleAppStoreNotification(env.deps, 'notification-jws-0123456789')).toBe(200);

    expect(((await refs(env.deps.db).account(pro.uid).get()).data() as AccountDoc).plan.state).toBe('active');
  });

  it('mirrors an expiry and a refund', async () => {
    const appAccountToken = await accountToken();
    env.appStore.addNotification('renew-jws-0123456789abcdef', { type: 'DID_RENEW', transaction: { productId: 'com.bellohub.pro.monthly', bundleId: 'com.bellohub', environment: 'Production', appAccountToken, expiresAt: env.clock.now() + DAY } });
    await handleAppStoreNotification(env.deps, 'renew-jws-0123456789abcdef');
    env.appStore.addNotification('refund-jws-0123456789abcdef', { type: 'REFUND', transaction: { productId: 'com.bellohub.pro.monthly', bundleId: 'com.bellohub', environment: 'Production', appAccountToken, expiresAt: env.clock.now() + DAY, revokedAt: env.clock.now() } });

    expect(await handleAppStoreNotification(env.deps, 'refund-jws-0123456789abcdef')).toBe(200);

    expect(((await refs(env.deps.db).account(pro.uid).get()).data() as AccountDoc).plan.state).toBe('revoked');
  });

  it('ignores a notification for an unknown account or product, rejects an unverifiable one, and retries when not configured', async () => {
    env.appStore.addNotification('stranger-jws-0123456789abc', { type: 'DID_RENEW', transaction: { productId: 'com.bellohub.pro.monthly', bundleId: 'com.bellohub', environment: 'Production', appAccountToken: crypto.randomUUID(), expiresAt: env.clock.now() + DAY } });
    expect(await handleAppStoreNotification(env.deps, 'stranger-jws-0123456789abc')).toBe(200);
    expect(await handleAppStoreNotification(env.deps, 'garbage-garbage-garbage-1234')).toBe(400);
    expect(await handleAppStoreNotification(env.deps, undefined)).toBe(400);

    const original = env.deps.appStore;
    env.deps.appStore = new UnconfiguredAppStoreVerifier();
    try {
      expect(await handleAppStoreNotification(env.deps, 'any-payload-0123456789abcdef')).toBe(503);
    } finally {
      env.deps.appStore = original;
    }
    // A check that failed for a reason Apple calls retryable (the online revocation check) is also a 503.
    env.appStore.nextError = new AppError('TRY_AGAIN');
    expect(await handleAppStoreNotification(env.deps, 'retry-payload-0123456789abcd')).toBe(503);
  });
});
