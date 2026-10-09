import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import type { RulesTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

// The emulator tests ARE the specification of firestore.rules (docs/11-BACKEND-FIREBASE.md section 5). Every rule has
// an allow case and a deny case; every privacy claim of docs/06 section 7 about the database has a test here.

const PROJECT_ID = 'demo-bellohub';
const rulesPath = fileURLToPath(new URL('../../../firestore.rules', import.meta.url));

let env: RulesTestEnvironment;

const ALICE = 'alice-uid';
const BOB = 'bob-uid';

const alice = () => env.authenticatedContext(ALICE).firestore();
const bob = () => env.authenticatedContext(BOB).firestore();
const anonymous = () => env.unauthenticatedContext().firestore();

beforeAll(async () => {
  env = await initializeTestEnvironment({ projectId: PROJECT_ID, firestore: { rules: readFileSync(rulesPath, 'utf8') } });
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const now = Timestamp.fromMillis(Date.UTC(2026, 9, 8));
    await setDoc(doc(db, 'accounts', ALICE), {
      slug: 'alice',
      locale: 'pt-BR',
      plan: { state: 'none' },
      registrations: { count: 3, freeLimit: 10 },
      inboxKeyring: [],
      deletion: {},
      banned: false
    });
    await setDoc(doc(db, 'accounts', BOB), { slug: 'bob', locale: 'en', plan: { state: 'active' }, registrations: { count: 1, freeLimit: 10 } });
    await setDoc(doc(db, 'accounts', ALICE, 'registrations', 'client-1'), { registeredAt: now });
    await setDoc(doc(db, 'accounts', BOB, 'registrations', 'client-9'), { registeredAt: now });
    await setDoc(doc(db, 'publicProfiles', 'alice'), { displayName: 'Alice', services: [] });
    await setDoc(doc(db, 'bookings', 'booking-alice'), { ownerUid: ALICE, client: { name: 'Ana', phone: '+5511900000001' } });
    await setDoc(doc(db, 'bookings', 'booking-bob'), { ownerUid: BOB, client: { name: 'Bia', phone: '+5511900000002' } });
    await setDoc(doc(db, 'inbox', ALICE, 'items', 'item-1'), { kind: 'intake', bookingId: 'booking-alice', envelope: { ct: 'x' } });
    await setDoc(doc(db, 'inbox', BOB, 'items', 'item-2'), { kind: 'intake', bookingId: 'booking-bob', envelope: { ct: 'y' } });
    await setDoc(doc(db, 'rescheduleRequests', 'req-alice'), { ownerUid: ALICE, bookingId: 'booking-alice' });
    await setDoc(doc(db, 'rescheduleRequests', 'req-bob'), { ownerUid: BOB, bookingId: 'booking-bob' });
    await setDoc(doc(db, 'waitlist', 'wait-alice'), { ownerUid: ALICE, name: 'Carla' });
    await setDoc(doc(db, 'waitlist', 'wait-bob'), { ownerUid: BOB, name: 'Dora' });
    await setDoc(doc(db, 'devices', ALICE, 'tokens', 'token-1'), {
      fcmToken: 'a'.repeat(40),
      platform: 'ios',
      lastSeenAt: now
    });
    for (const path of FUNCTION_ONLY) {
      await setDoc(doc(db, path), { ownerUid: ALICE, secret: true });
    }
  });
});

/** Documents that exist but that no client may touch. */
const FUNCTION_ONLY = [
  'slugs/alice',
  `availability/${ALICE}`,
  `intakeForms/${ALICE}`,
  'holds/hold-1',
  'portal/portal-1',
  `contacts/${ALICE}_abc`,
  `calendarLocks/${ALICE}`,
  'emailCodes/code-1',
  'emailProofs/proof-1',
  'idempotency/key-1',
  'rate/rate-1',
  'audit/audit-1'
];

describe('professionals cannot read each other', () => {
  it('lets a professional read her own account, not another one', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'accounts', ALICE)));
    await assertFails(getDoc(doc(bob(), 'accounts', ALICE)));
    await assertFails(getDoc(doc(anonymous(), 'accounts', ALICE)));
  });

  it('lets a professional read her own bookings and no one else', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'bookings', 'booking-alice')));
    await assertFails(getDoc(doc(alice(), 'bookings', 'booking-bob')));
    await assertFails(getDoc(doc(anonymous(), 'bookings', 'booking-alice')));
  });

  it('lets a professional query her bookings and refuses a query that could return another one', async () => {
    await assertSucceeds(getDocs(query(collection(alice(), 'bookings'), where('ownerUid', '==', ALICE))));
    await assertFails(getDocs(query(collection(alice(), 'bookings'), where('ownerUid', '==', BOB))));
    await assertFails(getDocs(collection(alice(), 'bookings')));
    await assertFails(getDocs(collection(anonymous(), 'bookings')));
  });

  it('keeps sealed envelopes readable only by their owner', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'inbox', ALICE, 'items', 'item-1')));
    await assertSucceeds(getDocs(collection(alice(), 'inbox', ALICE, 'items')));
    await assertFails(getDoc(doc(alice(), 'inbox', BOB, 'items', 'item-2')));
    await assertFails(getDocs(collection(alice(), 'inbox', BOB, 'items')));
    await assertFails(getDoc(doc(anonymous(), 'inbox', ALICE, 'items', 'item-1')));
  });

  it('refuses a collection group query over every mailbox', async () => {
    await assertFails(getDocs(collectionGroup(alice(), 'items')));
    await assertFails(getDocs(query(collectionGroup(alice(), 'items'), where('kind', '==', 'intake'))));
    await assertFails(getDocs(collectionGroup(alice(), 'tokens')));
    await assertFails(getDocs(collectionGroup(alice(), 'registrations')));
  });

  it('lets a professional read her own requests and waitlist and not another one', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'rescheduleRequests', 'req-alice')));
    await assertFails(getDoc(doc(alice(), 'rescheduleRequests', 'req-bob')));
    await assertSucceeds(getDocs(query(collection(alice(), 'waitlist'), where('ownerUid', '==', ALICE))));
    await assertFails(getDoc(doc(alice(), 'waitlist', 'wait-bob')));
    await assertFails(getDoc(doc(anonymous(), 'waitlist', 'wait-alice')));
  });

  it('lets a professional read her registration ledger and not another one', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'accounts', ALICE, 'registrations', 'client-1')));
    await assertSucceeds(getDocs(collection(alice(), 'accounts', ALICE, 'registrations')));
    await assertFails(getDoc(doc(alice(), 'accounts', BOB, 'registrations', 'client-9')));
    await assertFails(getDocs(collection(alice(), 'accounts', BOB, 'registrations')));
    await assertFails(getDoc(doc(anonymous(), 'accounts', ALICE, 'registrations', 'client-1')));
  });

  it('lets a professional read her own push tokens and no one else', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'devices', ALICE, 'tokens', 'token-1')));
    await assertFails(getDoc(doc(bob(), 'devices', ALICE, 'tokens', 'token-1')));
    await assertFails(getDoc(doc(anonymous(), 'devices', ALICE, 'tokens', 'token-1')));
  });
});

describe('no direct client writes to bookings, inbox and the other function-only data', () => {
  it('refuses every write to bookings, even by the owner of the booking', async () => {
    await assertFails(setDoc(doc(alice(), 'bookings', 'new'), { ownerUid: ALICE, status: 'confirmed' }));
    await assertFails(updateDoc(doc(alice(), 'bookings', 'booking-alice'), { status: 'cancelledByPro' }));
    await assertFails(deleteDoc(doc(alice(), 'bookings', 'booking-alice')));
    await assertFails(setDoc(doc(anonymous(), 'bookings', 'new'), { ownerUid: ALICE }));
    await assertFails(updateDoc(doc(bob(), 'bookings', 'booking-alice'), { status: 'declined' }));
  });

  it('refuses every write to the inbox, so an envelope can only be removed by acknowledging it', async () => {
    await assertFails(setDoc(doc(alice(), 'inbox', ALICE, 'items', 'forged'), { kind: 'intake' }));
    await assertFails(updateDoc(doc(alice(), 'inbox', ALICE, 'items', 'item-1'), { kind: 'checkin' }));
    await assertFails(deleteDoc(doc(alice(), 'inbox', ALICE, 'items', 'item-1')));
    await assertFails(setDoc(doc(anonymous(), 'inbox', ALICE, 'items', 'forged'), { kind: 'intake' }));
    await assertFails(setDoc(doc(bob(), 'inbox', ALICE, 'items', 'forged'), { kind: 'intake' }));
  });

  it('refuses every write to reschedule requests and the waitlist', async () => {
    await assertFails(setDoc(doc(alice(), 'rescheduleRequests', 'x'), { ownerUid: ALICE }));
    await assertFails(updateDoc(doc(alice(), 'rescheduleRequests', 'req-alice'), { status: 'accepted' }));
    await assertFails(deleteDoc(doc(alice(), 'rescheduleRequests', 'req-alice')));
    await assertFails(setDoc(doc(alice(), 'waitlist', 'x'), { ownerUid: ALICE }));
    await assertFails(updateDoc(doc(alice(), 'waitlist', 'wait-alice'), { status: 'offered' }));
    await assertFails(deleteDoc(doc(anonymous(), 'waitlist', 'wait-alice')));
  });

  it('refuses every write to the registration ledger, including deleting an entry to win a free slot back', async () => {
    await assertFails(setDoc(doc(alice(), 'accounts', ALICE, 'registrations', 'client-2'), { registeredAt: Timestamp.now() }));
    await assertFails(deleteDoc(doc(alice(), 'accounts', ALICE, 'registrations', 'client-1')));
    await assertFails(updateDoc(doc(alice(), 'accounts', ALICE, 'registrations', 'client-1'), { registeredAt: Timestamp.now() }));
  });

  it.each(FUNCTION_ONLY)('gives no client any access to %s', async (path) => {
    for (const db of [alice(), bob(), anonymous()]) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), { ownerUid: ALICE, tampered: true }));
      await assertFails(updateDoc(doc(db, path), { tampered: true }));
      await assertFails(deleteDoc(doc(db, path)));
    }
  });

  it('refuses unauthenticated writes anywhere', async () => {
    const paths = ['accounts/alice-uid', 'publicProfiles/alice', 'publicProfiles/new', 'bookings/new', 'devices/alice-uid/tokens/t', 'anything/else'];
    for (const path of paths) {
      await assertFails(setDoc(doc(anonymous(), path), { x: 1 }));
    }
  });

  it('denies a collection that the rules never heard of', async () => {
    await assertFails(getDoc(doc(alice(), 'surprise', 'one')));
    await assertFails(setDoc(doc(alice(), 'surprise', 'one'), { x: 1 }));
  });
});

describe('public reads are limited to published profiles', () => {
  it('lets anyone, signed in or not, fetch one profile by its slug', async () => {
    await assertSucceeds(getDoc(doc(anonymous(), 'publicProfiles', 'alice')));
    await assertSucceeds(getDoc(doc(bob(), 'publicProfiles', 'alice')));
  });

  it('refuses listing profiles, so professionals cannot be enumerated', async () => {
    await assertFails(getDocs(collection(anonymous(), 'publicProfiles')));
    await assertFails(getDocs(collection(alice(), 'publicProfiles')));
    await assertFails(getDocs(query(collection(anonymous(), 'publicProfiles'), where('displayName', '==', 'Alice'))));
  });

  it('refuses every write to a profile, even by its owner (a function validates and publishes it)', async () => {
    await assertFails(setDoc(doc(alice(), 'publicProfiles', 'alice'), { displayName: 'Evil' }));
    await assertFails(updateDoc(doc(alice(), 'publicProfiles', 'alice'), { displayName: 'Evil' }));
    await assertFails(deleteDoc(doc(alice(), 'publicProfiles', 'alice')));
    await assertFails(setDoc(doc(anonymous(), 'publicProfiles', 'new'), { displayName: 'Evil' }));
  });

  it('does not let the public read anything else', async () => {
    await assertFails(getDoc(doc(anonymous(), 'accounts', ALICE)));
    await assertFails(getDoc(doc(anonymous(), 'bookings', 'booking-alice')));
    await assertFails(getDoc(doc(anonymous(), 'availability', ALICE)));
    await assertFails(getDoc(doc(anonymous(), 'slugs', 'alice')));
  });
});

describe('sensitive account fields are never client-writable', () => {
  it('lets the owner change her language', async () => {
    await assertSucceeds(updateDoc(doc(alice(), 'accounts', ALICE), { locale: 'de' }));
  });

  it('refuses an unknown language', async () => {
    await assertFails(updateDoc(doc(alice(), 'accounts', ALICE), { locale: 'klingon' }));
    await assertFails(updateDoc(doc(alice(), 'accounts', ALICE), { locale: 5 }));
  });

  it.each([
    ['the plan state', { 'plan.state': 'active' }],
    ['the plan', { plan: { state: 'active', expiresAt: Timestamp.now() } }],
    ['the registration counter', { 'registrations.count': 0 }],
    ['the registrations object', { registrations: { count: 0, freeLimit: 1000 } }],
    ['the free limit', { 'registrations.freeLimit': 1000 }],
    ['the ban flag', { banned: true }],
    ['the slug', { slug: 'bob' }],
    ['the key ring', { inboxKeyring: [{ keyId: 'evil', pub: 'x' }] }],
    ['the deletion state', { deletion: { requestedAt: Timestamp.now() } }],
    ['the data region', { dataRegion: 'us' }],
    ['the phone', { phone: '+5511999999999' }],
    ['a made-up field', { whatever: true }]
  ])('refuses a change to %s', async (_label, patch) => {
    await assertFails(updateDoc(doc(alice(), 'accounts', ALICE), patch));
  });

  it('refuses a language change that carries another field with it', async () => {
    await assertFails(updateDoc(doc(alice(), 'accounts', ALICE), { locale: 'de', 'plan.state': 'active' }));
  });

  it('refuses another professional changing the account, and creating or deleting accounts', async () => {
    await assertFails(updateDoc(doc(bob(), 'accounts', ALICE), { locale: 'de' }));
    await assertFails(updateDoc(doc(anonymous(), 'accounts', ALICE), { locale: 'de' }));
    await assertFails(setDoc(doc(alice(), 'accounts', 'new-uid'), { locale: 'en' }));
    await assertFails(setDoc(doc(alice(), 'accounts', ALICE), { locale: 'en' }));
    await assertFails(deleteDoc(doc(alice(), 'accounts', ALICE)));
  });

  it('refuses listing accounts', async () => {
    await assertFails(getDocs(collection(alice(), 'accounts')));
  });
});

describe('push tokens', () => {
  const token = (extra: Record<string, unknown> = {}) => ({
    fcmToken: 'f'.repeat(64),
    platform: 'ios',
    lastSeenAt: Timestamp.now(),
    ...extra
  });

  it('lets the owner register, update and remove a device', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'devices', ALICE, 'tokens', 'iphone'), token({ locale: 'pt-BR' })));
    await assertSucceeds(updateDoc(doc(alice(), 'devices', ALICE, 'tokens', 'iphone'), { lastSeenAt: Timestamp.now() }));
    await assertSucceeds(deleteDoc(doc(alice(), 'devices', ALICE, 'tokens', 'iphone')));
  });

  it('refuses another user or an anonymous visitor writing into her devices', async () => {
    await assertFails(setDoc(doc(bob(), 'devices', ALICE, 'tokens', 'x'), token()));
    await assertFails(setDoc(doc(anonymous(), 'devices', ALICE, 'tokens', 'x'), token()));
    await assertFails(deleteDoc(doc(bob(), 'devices', ALICE, 'tokens', 'token-1')));
  });

  it.each([
    ['an unknown field', token({ extra: 1 })],
    ['a missing field', { fcmToken: 'f'.repeat(64), platform: 'ios' }],
    ['another platform', token({ platform: 'android' })],
    ['a short token', token({ fcmToken: 'short' })],
    ['a huge token', token({ fcmToken: 'f'.repeat(5000) })],
    ['a token that is not a string', token({ fcmToken: 42 })],
    ['a bad locale', token({ locale: 'xx' })],
    ['a time that is not a timestamp', token({ lastSeenAt: 'yesterday' })]
  ])('refuses %s', async (_label, data) => {
    await assertFails(setDoc(doc(alice(), 'devices', ALICE, 'tokens', 'bad'), data));
  });
});
