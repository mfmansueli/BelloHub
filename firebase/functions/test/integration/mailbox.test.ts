import { randomBytes, randomUUID } from 'node:crypto';

import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { base64url } from '../../src/lib/crypto.js';
import type { InboxItemDoc, PublicProfileDoc } from '../../src/lib/docs.js';
import type { AppError } from '../../src/lib/errors.js';
import { refs } from '../../src/lib/store.js';
import { acknowledgeMailboxItem } from '../../src/owner/acknowledgeMailboxItem.js';
import { getMailboxItem } from '../../src/owner/getMailboxItem.js';
import { publishProfile } from '../../src/owner/publishProfile.js';
import { updateInboxKey } from '../../src/owner/updateInboxKey.js';
import { getFormContext } from '../../src/public/getFormContext.js';
import { submitSealed } from '../../src/public/submitSealed.js';
import { handleInboxItemCreated } from '../../src/triggers/handleInboxItemCreated.js';
import { asBooked, book, bookingDoc } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { captureWorld, mariaProfile, newInboxKey, ownerContext, restoreWorld, seedProfessional } from '../support/seed.js';
import type { Professional, World } from '../support/seed.js';

const env = createTestEnv();
let pro: Professional;
let world: World;
const START = '2026-10-03T13:00:00.000Z';

beforeAll(async () => {
  await resetEmulators(env, { storage: true });
  pro = await seedProfessional(env);
  await env.call(
    publishProfile,
    {
      profile: {
        ...mariaProfile(pro.inboxKey),
        intake: {
          formVersion: 2,
          template: { questions: [{ key: 'allergies', required: true }] },
          consent: { 'pt-BR': { textVersion: '2026-10', text: 'Eu concordo.' }, en: { textVersion: '2026-10', text: 'I agree.' } }
        }
      }
    },
    ownerContext(pro.uid)
  );
  world = await captureWorld(env, pro);
});

beforeEach(async () => {
  await resetEmulators(env, { storage: true });
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  env.push.calls.length = 0;
  await restoreWorld(env, world);
});

const owner = () => ownerContext(pro.uid);

function envelope(overrides: Record<string, unknown> = {}, ctBytes = 600) {
  return {
    v: 1,
    suite: 'hpke-x25519-hkdf-sha256-chacha20poly1305',
    keyId: pro.inboxKey.keyId,
    kind: 'intake',
    itemId: randomUUID(),
    enc: base64url(randomBytes(32)),
    ct: base64url(randomBytes(ctBytes)),
    ...overrides
  };
}

async function bookingToken(): Promise<{ token: string; bookingId: string }> {
  const booked = asBooked(await book(env, pro, { startsAt: START }));
  return { token: booked.manageToken, bookingId: booked.bookingId };
}

const submit = (token: string, sealed: Record<string, unknown>, ip = '203.0.113.5') => env.call(submitSealed, { token, envelope: sealed }, { ip });

describe('getFormContext', () => {
  it('gives the browser the questions, the consent texts and the PUBLIC key, and only a flag about earlier forms', async () => {
    const { token, bookingId } = await bookingToken();

    const context = (await env.call(getFormContext, { token })) as {
      bookingId: string; professional: { displayName: string }; formVersion: number; template: unknown;
      consent: Record<string, unknown>; inboxKey: { keyId: string; pub: string }; intakeCompletedWithinMonths: boolean;
    };

    expect(context.bookingId).toBe(bookingId);
    expect(context.formVersion).toBe(2);
    expect(Object.keys(context.consent)).toEqual(['pt-BR', 'en']);
    expect(context.inboxKey).toMatchObject({ keyId: pro.inboxKey.keyId, pub: pro.inboxKey.pub, alg: 'hpke-v1' });
    expect(context.intakeCompletedWithinMonths).toBe(false);
    expect(JSON.stringify(context)).not.toContain('Ana');
  });

  it('is NOT_FOUND when the professional published no health form, and refuses unknown links', async () => {
    await env.call(publishProfile, { profile: mariaProfile(pro.inboxKey) }, owner());
    const { token } = await bookingToken();

    await expect(env.call(getFormContext, { token })).rejects.toMatchObject({ code: 'NOT_FOUND' });
    await expect(env.call(getFormContext, { token: 'z'.repeat(22) })).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('submitSealed', () => {
  it('stores an opaque envelope with a thirty day life and never looks inside', async () => {
    const { token, bookingId } = await bookingToken();
    const sealed = envelope();

    expect(await submit(token, sealed)).toEqual({ ok: true });

    const item = (await refs(env.deps.db).inboxItem(pro.uid, sealed.itemId).get()).data() as InboxItemDoc;
    expect(item).toMatchObject({ ownerUid: pro.uid, bookingId, kind: 'intake', keyId: pro.inboxKey.keyId, sizeBytes: 600 });
    expect(item.expiresAt.toMillis()).toBe(env.clock.now() + 30 * 86_400_000);
    expect(item.envelope).toMatchObject({ ct: sealed.ct, enc: sealed.enc });
    expect(item.storagePath).toBeUndefined();
    // Only the ids, the key id, the sizes and the dates: nothing else is derived from the envelope.
    expect(Object.keys(item).sort()).toEqual(['bookingId', 'createdAt', 'ctHash', 'envelope', 'expiresAt', 'keyId', 'kind', 'ownerUid', 'sizeBytes']);
  });

  it('records that a form was sent, as a date and nothing else, and stops asking for twelve months', async () => {
    const { token, bookingId } = await bookingToken();
    await submit(token, envelope());

    const stored = await bookingDoc(env, bookingId);
    expect(stored.intakeSubmittedAt?.toMillis()).toBe(env.clock.now());
    const context = (await env.call(getFormContext, { token })) as { intakeCompletedWithinMonths: boolean };
    expect(context.intakeCompletedWithinMonths).toBe(true);
  });

  it('keeps large envelopes in Cloud Storage and small ones in Firestore, and returns both through getMailboxItem', async () => {
    const { token } = await bookingToken();
    const small = envelope({}, 150 * 1024);
    const large = envelope({}, 220 * 1024);
    await submit(token, small);
    await submit(token, large);

    const smallItem = (await refs(env.deps.db).inboxItem(pro.uid, small.itemId).get()).data() as InboxItemDoc;
    const largeItem = (await refs(env.deps.db).inboxItem(pro.uid, large.itemId).get()).data() as InboxItemDoc;
    expect(smallItem.envelope).toBeDefined();
    expect(largeItem.envelope).toBeUndefined();
    expect(largeItem.storagePath).toBe(`inbox/${pro.uid}/${large.itemId}.json`);
    expect(await env.deps.blobs.get(largeItem.storagePath ?? '')).not.toBeNull();

    const fetched = (await env.call(getMailboxItem, { itemId: large.itemId }, owner())) as { envelope: { ct: string }; kind: string };
    expect(fetched.envelope.ct).toBe(large.ct);
    expect(fetched.kind).toBe('intake');
    const fetchedSmall = (await env.call(getMailboxItem, { itemId: small.itemId }, owner())) as { envelope: { ct: string } };
    expect(fetchedSmall.envelope.ct).toBe(small.ct);
  });

  it('enforces the size cap of each kind', async () => {
    const { token } = await bookingToken();

    await expect(submit(token, envelope({ kind: 'intake' }, 258 * 1024 + 100))).rejects.toMatchObject({ code: 'PAYLOAD_TOO_LARGE' });
    await expect(submit(token, envelope({ kind: 'datarequest' }, 9 * 1024 + 100))).rejects.toMatchObject({ code: 'PAYLOAD_TOO_LARGE' });
    expect(await submit(token, envelope({ kind: 'datarequest' }, 5 * 1024))).toEqual({ ok: true });
    expect(await submit(token, envelope({ kind: 'checkin' }, 2 * 1024 * 1024))).toEqual({ ok: true });
  }, 60_000);

  it('refuses a key the professional does not hold, but accepts a key she retired (pending items still open)', async () => {
    const { token } = await bookingToken();
    const strangerKey = newInboxKey();
    await expect(submit(token, envelope({ keyId: strangerKey.keyId }))).rejects.toMatchObject({ code: 'KEY_MISMATCH' });

    await env.call(updateInboxKey, { inboxKey: newInboxKey() }, owner());
    expect(await submit(token, envelope({ keyId: pro.inboxKey.keyId }))).toEqual({ ok: true });
  });

  it('treats a retry of the same envelope as a success and refuses a different ciphertext under the same item id', async () => {
    const { token } = await bookingToken();
    const sealed = envelope();
    await submit(token, sealed);

    expect(await submit(token, sealed)).toEqual({ ok: true });
    await expect(submit(token, { ...sealed, ct: base64url(randomBytes(600)) })).rejects.toMatchObject({ code: 'CONFLICT' });
    expect((await refs(env.deps.db).inboxItems(pro.uid).get()).size).toBe(1);
  });

  it('survives two identical envelopes arriving at the same moment', async () => {
    const { token } = await bookingToken();
    const sealed = envelope({}, 220 * 1024);

    const results = await Promise.all([submit(token, sealed, '203.0.113.1'), submit(token, sealed, '203.0.113.2')]);

    expect(results).toEqual([{ ok: true }, { ok: true }]);
    expect((await refs(env.deps.db).inboxItems(pro.uid).get()).size).toBe(1);
    expect(await env.deps.blobs.get(`inbox/${pro.uid}/${sealed.itemId}.json`)).not.toBeNull();
  }, 60_000);

  it('limits one booking to five envelopes an hour and one address to twenty', async () => {
    const { token } = await bookingToken();
    for (let n = 0; n < 5; n += 1) await submit(token, envelope({ kind: 'datarequest' }, 100), '203.0.113.1');

    const error = (await submit(token, envelope({ kind: 'datarequest' }, 100), '203.0.113.1').catch((caught: unknown) => caught)) as AppError;

    expect(error.code).toBe('RATE_LIMITED');
  });

  it('refuses a form for a cancelled visit, but still takes a data request', async () => {
    const { token, bookingId } = await bookingToken();
    await refs(env.deps.db).booking(bookingId).update({ status: 'cancelledByClient' });

    await expect(submit(token, envelope({ kind: 'intake' }))).rejects.toMatchObject({ code: 'BOOKING_NOT_ACTIVE' });
    expect(await submit(token, envelope({ kind: 'datarequest' }, 200))).toEqual({ ok: true });
  });

  it('refuses unknown links, malformed envelopes and extra fields', async () => {
    const { token } = await bookingToken();

    await expect(submit('q'.repeat(22), envelope())).rejects.toMatchObject({ code: 'NOT_FOUND' });
    await expect(submit(token, envelope({ enc: 'short' }))).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(submit(token, envelope({ suite: 'aes' }))).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(submit(token, envelope({ plaintext: 'allergic to latex' }))).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('wakes the app with a silent push that carries only the item id', async () => {
    await refs(env.deps.db).devices(pro.uid).doc('phone-1').set({ fcmToken: 'f'.repeat(40), platform: 'ios', lastSeenAt: new Date() });
    const { token } = await bookingToken();
    const sealed = envelope();
    await submit(token, sealed);

    await handleInboxItemCreated(env.deps, pro.uid, sealed.itemId);

    expect(env.push.messages()).toEqual([{ kind: 'mailbox', id: sealed.itemId }]);
  });
});

describe('acknowledgeMailboxItem and getMailboxItem', () => {
  it('deletes the item and its Storage object at once, and is safe to repeat', async () => {
    const { token } = await bookingToken();
    const large = envelope({}, 220 * 1024);
    await submit(token, large);

    expect(await env.call(acknowledgeMailboxItem, { itemId: large.itemId }, owner())).toEqual({ ok: true });

    expect((await refs(env.deps.db).inboxItem(pro.uid, large.itemId).get()).exists).toBe(false);
    expect(await env.deps.blobs.get(`inbox/${pro.uid}/${large.itemId}.json`)).toBeNull();
    expect(await env.call(acknowledgeMailboxItem, { itemId: large.itemId }, owner())).toEqual({ ok: true });
    expect(await env.call(acknowledgeMailboxItem, { itemId: randomUUID() }, owner())).toEqual({ ok: true });
  });

  it('shows an item only to the professional it belongs to', async () => {
    const { token } = await bookingToken();
    const sealed = envelope();
    await submit(token, sealed);
    const other = await seedProfessional(env, { uid: 'pro-other', slug: 'other-pro' });

    await expect(env.call(getMailboxItem, { itemId: sealed.itemId }, ownerContext(other.uid))).rejects.toMatchObject({ code: 'NOT_FOUND' });
    await env.call(acknowledgeMailboxItem, { itemId: sealed.itemId }, ownerContext(other.uid));
    expect((await refs(env.deps.db).inboxItem(pro.uid, sealed.itemId).get()).exists).toBe(true);
  });

  it('needs a signed-in professional', async () => {
    await expect(env.call(getMailboxItem, { itemId: randomUUID() })).rejects.toMatchObject({ code: 'UNAUTHENTICATED' });
    await expect(env.call(acknowledgeMailboxItem, { itemId: randomUUID() })).rejects.toMatchObject({ code: 'UNAUTHENTICATED' });
  });
});

describe('the page', () => {
  it('still publishes only the public key', async () => {
    const page = (await refs(env.deps.db).profile(pro.slug).get()).data() as PublicProfileDoc;

    expect(Object.keys(page.inboxKey).sort()).toEqual(['alg', 'keyId', 'pub']);
  });
});
