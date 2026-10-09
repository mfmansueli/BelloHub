import { randomBytes, randomUUID } from 'node:crypto';

import type { Firestore } from 'firebase-admin/firestore';
import { beforeEach, describe, expect, it } from 'vitest';

import { base64url } from '../../src/lib/crypto.js';
import { runCleanup } from '../../src/jobs/cleanup.js';
import { phoneHashOf } from '../../src/lib/emailProof.js';
import { refs, ts } from '../../src/lib/store.js';
import { deleteAccount } from '../../src/owner/deleteAccount.js';
import { deleteClientServerData } from '../../src/owner/deleteClientServerData.js';
import { publishPortal } from '../../src/owner/publishPortal.js';
import { registerDevice } from '../../src/owner/registerDevice.js';
import { reserveRegistration } from '../../src/owner/reserveRegistration.js';
import { joinWaitlist } from '../../src/public/joinWaitlist.js';
import { submitSealed } from '../../src/public/submitSealed.js';
import { holdSlot } from '../../src/public/holdSlot.js';
import { requestReschedule } from '../../src/token/requestReschedule.js';
import { ANA, asBooked, BIA, book, bookingDoc } from '../support/booking.js';
import { createTestEnv, envelopeBlobs, PEPPER, resetEmulators } from '../support/env.js';
import { ownerContext, publishProfileWithIntake, seedProfessional, SERVICE } from '../support/seed.js';
import type { Professional } from '../support/seed.js';

const env = createTestEnv();
let pro: Professional;
let other: Professional;
const HOUR = 3_600_000;
const START = '2026-10-03T13:00:00.000Z';
const LATER = '2026-10-03T17:00:00.000Z';

beforeEach(async () => {
  await resetEmulators(env, { storage: true, auth: true });
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  pro = await seedProfessional(env);
  other = await seedProfessional(env, { uid: 'pro-other', slug: 'other-pro' });
});

interface Found {
  path: string;
  text: string;
}

/** Every document in the database, at any depth, as a path and its JSON. */
async function everything(db: Firestore): Promise<Found[]> {
  const found: Found[] = [];
  const walk = async (collections: FirebaseFirestore.CollectionReference[]): Promise<void> => {
    for (const collection of collections) {
      for (const ref of await collection.listDocuments()) {
        const snapshot = await ref.get();
        if (snapshot.exists) found.push({ path: ref.path, text: JSON.stringify(snapshot.data()) });
        await walk(await ref.listCollections());
      }
    }
  };
  await walk(await db.listCollections());
  return found;
}

const sealedEnvelope = (kind: 'intake' | 'checkin', bytes: number) => ({
  v: 1,
  suite: 'hpke-x25519-hkdf-sha256-chacha20poly1305',
  keyId: pro.inboxKey.keyId,
  kind,
  itemId: randomUUID(),
  enc: base64url(randomBytes(32)),
  ct: base64url(randomBytes(bytes))
});

/** Gives the professional a footprint in every collection and in Storage and Auth. */
async function fillAccount(): Promise<{ aBooking: string; aToken: string; large: string }> {
  await publishProfileWithIntake(env, pro);
  await env.deps.auth.createUser({ uid: pro.uid, phoneNumber: '+5511900000000' });
  await env.call(registerDevice, { fcmToken: `fcm-${'a'.repeat(60)}`, platform: 'ios' }, ownerContext(pro.uid));
  await env.call(reserveRegistration, { clientId: randomUUID(), phone: '+5511911110000' }, ownerContext(pro.uid));

  const first = asBooked(await book(env, pro, { startsAt: START }));
  asBooked(await book(env, pro, { client: BIA, startsAt: LATER }));
  const small = sealedEnvelope('intake', 800);
  const large = sealedEnvelope('checkin', 220 * 1024);
  await env.call(submitSealed, { token: first.manageToken, envelope: small });
  await env.call(submitSealed, { token: first.manageToken, envelope: large });
  await env.call(holdSlot, { slug: pro.slug, serviceId: SERVICE.glowFacial, startsAt: '2026-10-03T19:00:00.000Z', holdKey: 'hold-key-0123456789abcdef' });
  await env.call(joinWaitlist, { slug: pro.slug, name: 'Paula', phone: '+5511955550000', locale: 'pt-BR', dayFrom: '2026-10-03', dayTo: '2026-10-05' });
  const portalToken = base64url(Buffer.from('0123456789abcdef'));
  await env.call(publishPortal, { token: portalToken, clientRef: randomUUID(), content: { clientName: 'Ana', past: [], aftercare: [], products: [] } }, ownerContext(pro.uid));
  env.clock.set(Date.parse(START) - 10 * HOUR);
  await env.call(requestReschedule, { token: first.manageToken, startsAt: '2026-10-03T19:30:00.000Z' });
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  return { aBooking: first.bookingId, aToken: first.manageToken, large: large.itemId };
}

describe('deleteAccount (D30)', () => {
  it('leaves no document, no Storage object and no Auth user of the professional anywhere', async () => {
    const footprint = await fillAccount();
    const before = await everything(env.deps.db);
    for (const collection of ['accounts/', 'bookings/', 'holds/', 'inbox/', 'waitlist/', 'rescheduleRequests/', 'portal/', 'contacts/', 'devices/', 'availability/', 'publicProfiles/', 'slugs/', 'calendarLocks/', 'intakeForms/']) {
      expect(before.some((found) => found.path.startsWith(collection) && (found.text.includes(pro.uid) || found.path.includes(pro.uid) || found.path.includes('maria'))), collection).toBe(true);
    }
    expect(await envelopeBlobs(env, pro.uid, footprint.large)).toHaveLength(1);

    expect(await env.call(deleteAccount, { confirm: true }, ownerContext(pro.uid))).toEqual({ ok: true, appleRevocation: 'skipped' });

    const after = await everything(env.deps.db);
    const stillHers = after.filter(
      (found) => found.path.includes(pro.uid) || found.text.includes(pro.uid) || found.path.includes('publicProfiles/maria') || found.path.includes('slugs/maria')
    );
    expect(stillHers).toEqual([]);
    expect(await envelopeBlobs(env, pro.uid, footprint.large)).toHaveLength(0);
    const left = await env.deps.blobs.list(`inbox/${pro.uid}/`);
    expect(left.paths).toEqual([]);
    await expect(env.deps.auth.getUser(pro.uid)).rejects.toMatchObject({ code: 'auth/user-not-found' });
    // What may remain is anonymous (rate counters and audit events keyed by hashes) or another professional's.
    const hers = after.filter((found) => !found.path.startsWith('rate/') && !found.path.startsWith('audit/'));
    expect(hers.every((found) => found.path.includes(other.uid) || found.text.includes(other.uid) || found.path.includes('other-pro'))).toBe(true);
  });

  it('never touches another professional\'s data', async () => {
    await fillAccount();
    asBooked(await book(env, other, { slug: other.slug, startsAt: START, client: ANA }));
    const theirsBefore = (await everything(env.deps.db)).filter((found) => found.path.includes(other.uid) || found.text.includes(other.uid)).length;
    expect(theirsBefore).toBeGreaterThan(3);

    await env.call(deleteAccount, { confirm: true }, ownerContext(pro.uid));

    const theirsAfter = (await everything(env.deps.db)).filter((found) => found.path.includes(other.uid) || found.text.includes(other.uid)).length;
    expect(theirsAfter).toBe(theirsBefore);
    expect((await env.call((await import('../../src/public/getPublicPage.js')).getPublicPage, { slug: other.slug }))).toBeDefined();
  });

  it('is safe to call again, and for an account that never existed', async () => {
    await fillAccount();
    await env.call(deleteAccount, { confirm: true }, ownerContext(pro.uid));

    expect(await env.call(deleteAccount, { confirm: true }, ownerContext(pro.uid))).toEqual({ ok: true, appleRevocation: 'skipped' });
    expect(await env.call(deleteAccount, { confirm: true }, ownerContext('never-existed'))).toEqual({ ok: true, appleRevocation: 'skipped' });
  });

  it('requires an explicit confirmation and a signed-in professional', async () => {
    await expect(env.call(deleteAccount, { confirm: false }, ownerContext(pro.uid))).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(deleteAccount, {}, ownerContext(pro.uid))).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(deleteAccount, { confirm: true })).rejects.toMatchObject({ code: 'UNAUTHENTICATED' });
  });

  it('finishes an interrupted deletion by itself: the account carries the request until the job completes it', async () => {
    await fillAccount();
    await refs(env.deps.db).account(pro.uid).update({ 'deletion.requestedAt': ts(env.clock.now()) });

    const report = await runCleanup(env.deps, env.clock.now() + HOUR);

    expect(report.accounts).toBe(1);
    const left = (await everything(env.deps.db)).filter((found) => found.path.includes(pro.uid) || found.text.includes(pro.uid));
    expect(left).toEqual([]);
  });

  it('frees the address, so a new account can claim it', async () => {
    await env.call(deleteAccount, { confirm: true }, ownerContext(pro.uid));

    const again = await seedProfessional(env, { uid: 'pro-new', slug: 'maria' });
    expect(again.slug).toBe('maria');
  });
});

describe('deleteClientServerData', () => {
  it('removes one client\'s bookings, sealed items, requests, waitlist entry, portal and contact, and keeps the others', async () => {
    const mine = await fillAccount();
    const ana = await bookingDoc(env, mine.aBooking);
    const portals = await refs(env.deps.db).portals().get();
    const portalRef = (portals.docs[0]?.data() as { clientRef: string }).clientRef;

    const result = (await env.call(deleteClientServerData, { phone: ANA.phone, portalClientRef: portalRef }, ownerContext(pro.uid))) as {
      deleted: { bookings: number; mailboxItems: number; requests: number; contacts: number; portals: number };
    };

    expect(result.deleted).toMatchObject({ bookings: 1, mailboxItems: 2, requests: 1, contacts: 1, portals: 1 });
    expect((await refs(env.deps.db).booking(mine.aBooking).get()).exists).toBe(false);
    expect(await envelopeBlobs(env, pro.uid, mine.large)).toHaveLength(0);
    expect((await refs(env.deps.db).contact(pro.uid, ana.phoneHash).get()).exists).toBe(false);
    // The other client (Bia) and the account itself are untouched.
    expect((await refs(env.deps.db).bookings().where('phoneHash', '==', phoneHashOf(PEPPER, BIA.phone)).get()).size).toBe(1);
    expect((await refs(env.deps.db).account(pro.uid).get()).exists).toBe(true);
  });

  it('removes a waitlist entry by phone', async () => {
    await env.call(joinWaitlist, { slug: pro.slug, name: 'Paula', phone: '+5511955550000', locale: 'pt-BR', dayFrom: '2026-10-03', dayTo: '2026-10-05' });

    const result = (await env.call(deleteClientServerData, { phone: '+5511955550000' }, ownerContext(pro.uid))) as { deleted: { waitlist: number } };

    expect(result.deleted.waitlist).toBe(1);
    expect((await refs(env.deps.db).waitlist().get()).size).toBe(0);
  });

  it('deletes by booking id too, and ignores ids that are not hers', async () => {
    const mine = asBooked(await book(env, pro, { startsAt: START }));
    const theirs = asBooked(await book(env, other, { slug: other.slug, startsAt: START }));

    const result = (await env.call(deleteClientServerData, { bookingIds: [mine.bookingId, theirs.bookingId] }, ownerContext(pro.uid))) as { deleted: { bookings: number } };

    expect(result.deleted.bookings).toBe(1);
    expect((await refs(env.deps.db).booking(theirs.bookingId).get()).exists).toBe(true);
  });

  it('asks for something to delete', async () => {
    await expect(env.call(deleteClientServerData, {}, ownerContext(pro.uid))).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('leaves a delete trace without personal data', async () => {
    await env.call(deleteClientServerData, { phone: ANA.phone }, ownerContext(pro.uid));

    const audits = (await refs(env.deps.db).audits().get()).docs.map((doc) => JSON.stringify(doc.data()));
    expect(audits.join('')).toContain('clientDataDeleted');
    expect(audits.join('')).not.toContain(ANA.phone);
    expect(audits.join('')).not.toContain(pro.uid);
  });
});
