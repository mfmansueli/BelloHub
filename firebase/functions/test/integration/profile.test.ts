import { randomUUID } from 'node:crypto';

import { beforeEach, describe, expect, it } from 'vitest';

import { base64url, sha256Hex } from '../../src/lib/crypto.js';
import type { AccountDoc, AvailabilityDoc, PortalDoc, PublicProfileDoc } from '../../src/lib/docs.js';
import { refs } from '../../src/lib/store.js';
import { claimSlug } from '../../src/owner/claimSlug.js';
import { ensureAccount } from '../../src/owner/ensureAccount.js';
import { isSlugAvailable } from '../../src/owner/isSlugAvailable.js';
import { publishAvailability } from '../../src/owner/publishAvailability.js';
import { publishPortal } from '../../src/owner/publishPortal.js';
import { publishProfile } from '../../src/owner/publishProfile.js';
import { registerDevice } from '../../src/owner/registerDevice.js';
import { unregisterDevice } from '../../src/owner/unregisterDevice.js';
import { updateInboxKey } from '../../src/owner/updateInboxKey.js';
import { getPortal } from '../../src/public/getPortal.js';
import { getPublicPage } from '../../src/public/getPublicPage.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { mariaAvailability, mariaProfile, newInboxKey, ownerContext, SERVICE, seedProfessional } from '../support/seed.js';
import type { Professional } from '../support/seed.js';

const env = createTestEnv();
let pro: Professional;
const who = () => ownerContext(pro.uid);
const DAY = 86_400_000;

beforeEach(async () => {
  await resetEmulators(env);
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  pro = await seedProfessional(env);
});

async function account(uid = pro.uid): Promise<AccountDoc> {
  return (await refs(env.deps.db).account(uid).get()).data() as AccountDoc;
}

describe('slugs', () => {
  it('claims an address and keeps it unique', async () => {
    const other = ownerContext('pro-other');
    await env.call(ensureAccount, { countryCode: 'BR', locale: 'pt-BR' }, other);

    await expect(env.call(claimSlug, { slug: 'maria' }, other)).rejects.toMatchObject({ code: 'SLUG_TAKEN' });
    expect(await env.call(claimSlug, { slug: 'maria-souza' }, other)).toEqual({ slug: 'maria-souza' });
    expect(await env.call(claimSlug, { slug: 'maria' }, who())).toEqual({ slug: 'maria' });
  });

  it('lets only one of two simultaneous claims win', async () => {
    const a = ownerContext('pro-a');
    const b = ownerContext('pro-b');

    const results = await Promise.allSettled([env.call(claimSlug, { slug: 'new-place' }, a), env.call(claimSlug, { slug: 'new-place' }, b)]);

    expect(results.filter((result) => result.status === 'fulfilled')).toHaveLength(1);
    expect(results.filter((result) => result.status === 'rejected')).toHaveLength(1);
    expect((await refs(env.deps.db).slug('new-place').get()).exists).toBe(true);
  });

  it('releases the old address and removes the old page when she changes it', async () => {
    await env.call(claimSlug, { slug: 'maria-new' }, who());

    expect((await refs(env.deps.db).slug('maria').get()).exists).toBe(false);
    expect((await refs(env.deps.db).profile('maria').get()).exists).toBe(false);
    expect((await account()).slug).toBe('maria-new');
    await expect(env.call(getPublicPage, { slug: 'maria' })).rejects.toMatchObject({ code: 'NOT_FOUND' });
    // The old address can be claimed by someone else now.
    expect(await env.call(claimSlug, { slug: 'maria' }, ownerContext('pro-other'))).toEqual({ slug: 'maria' });
  });

  it('answers "is it free" for taken, reserved, invalid and her own address', async () => {
    expect(await env.call(isSlugAvailable, { slug: 'maria' }, who())).toEqual({ available: true });
    expect(await env.call(isSlugAvailable, { slug: 'maria' }, ownerContext('pro-other'))).toEqual({ available: false, reason: 'taken' });
    expect(await env.call(isSlugAvailable, { slug: 'admin' }, who())).toEqual({ available: false, reason: 'reserved' });
    expect(await env.call(isSlugAvailable, { slug: 'No Spaces!' }, who())).toEqual({ available: false, reason: 'invalid' });
    expect(await env.call(isSlugAvailable, { slug: 'a--b' }, who())).toEqual({ available: false, reason: 'invalid' });
    expect(await env.call(isSlugAvailable, { slug: 'ab' }, who())).toEqual({ available: false, reason: 'invalid' });
    expect(await env.call(isSlugAvailable, { slug: 'free-address' }, who())).toEqual({ available: true });
  });

  it.each(['m', 'p', 'api', 'www', 'UPPER', 'has space', '-lead', 'trail-', 'ab'])('refuses the address %s', async (slug) => {
    await expect(env.call(claimSlug, { slug }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });
});

describe('publishProfile', () => {
  it('publishes a page with timestamps converted and no owner id', async () => {
    const stored = (await refs(env.deps.db).profile('maria').get()).data() as PublicProfileDoc;

    expect(stored.displayName).toBe('Maria Souza');
    expect(stored.updatedAt.toMillis()).toBe(env.clock.now());
    expect(JSON.stringify(stored)).not.toContain(pro.uid);
    expect(stored.inboxKey).toEqual(pro.inboxKey);
  });

  it('keeps the health form out of the public page, in a function-only document', async () => {
    const intake = { formVersion: 3, template: { questions: [{ key: 'allergies', label: { en: 'Any allergies?' } }] }, consent: { en: { textVersion: '2026-10', text: 'I agree' } } };
    await env.call(publishProfile, { profile: { ...mariaProfile(pro.inboxKey), intake } }, who());

    const page = (await refs(env.deps.db).profile('maria').get()).data();
    expect(JSON.stringify(page)).not.toContain('allergies');
    expect((await refs(env.deps.db).intakeForm(pro.uid).get()).data()).toMatchObject({ formVersion: 3, ownerUid: pro.uid });
    expect(((await env.call(getPublicPage, { slug: 'maria' })) as { intakeAvailable: boolean }).intakeAvailable).toBe(true);

    await env.call(publishProfile, { profile: mariaProfile(pro.inboxKey) }, who());
    expect((await refs(env.deps.db).intakeForm(pro.uid).get()).exists).toBe(false);
  });

  it('needs a claimed address', async () => {
    const stranger = ownerContext('pro-without-slug');

    await expect(env.call(publishProfile, { profile: mariaProfile(pro.inboxKey) }, stranger)).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('refuses an inbox key whose id is not the hash of the key', async () => {
    const forged = { ...pro.inboxKey, keyId: 'AAAAAAAAAAA' };

    await expect(env.call(publishProfile, { profile: mariaProfile(forged) }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('refuses duplicate service ids, a duplicate language and an unknown time zone', async () => {
    const duplicated = mariaProfile(pro.inboxKey);
    const service = duplicated.services[0];
    if (!service) throw new Error('fixture');

    await expect(env.call(publishProfile, { profile: { ...duplicated, services: [service, service] } }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(publishProfile, { profile: { ...duplicated, locales: ['en', 'en'] } }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(publishProfile, { profile: { ...duplicated, timeZoneID: 'Mars/Base' } }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('refuses a field that has no place on a public page, such as a client name or a note', async () => {
    const profile = { ...mariaProfile(pro.inboxKey), clients: [{ name: 'Ana' }], privateNote: 'x' };

    const error = await env.call(publishProfile, { profile }, who()).catch((caught: unknown) => caught);

    expect((error as { code: string }).code).toBe('INVALID_ARGUMENT');
  });

  it('strips control and invisible characters from text, and refuses oversized pages and photos', async () => {
    const control = String.fromCharCode(0);
    const bidiOverride = String.fromCharCode(0x202e);
    const zeroWidth = String.fromCharCode(0x200b);
    const dirty = mariaProfile(pro.inboxKey, { bio: `Hello${control} wor${bidiOverride}ld${zeroWidth}` });
    await env.call(publishProfile, { profile: dirty }, who());
    expect(((await refs(env.deps.db).profile('maria').get()).data() as PublicProfileDoc).bio).toBe('Hello world');

    const huge = mariaProfile(pro.inboxKey, { intake: { formVersion: 1, template: { blob: 'x'.repeat(250_000) }, consent: {} } });
    await expect(env.call(publishProfile, { profile: huge }, who())).rejects.toMatchObject({ code: 'PAYLOAD_TOO_LARGE' });
    const photo = `data:image/jpeg;base64,${'A'.repeat(170_000)}`;
    await expect(env.call(publishProfile, { profile: mariaProfile(pro.inboxKey, { photo }) }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('records a changed inbox key in the ring, keeps the old one and writes an audit event without values', async () => {
    const next = newInboxKey();

    await env.call(publishProfile, { profile: mariaProfile(next) }, who());

    const ring = (await account()).inboxKeyring;
    expect(ring.map((entry) => entry.keyId)).toEqual([pro.inboxKey.keyId, next.keyId]);
    expect(ring[0]?.retiredAt).toBeDefined();
    expect(ring[1]?.retiredAt).toBeUndefined();
    const audits = (await refs(env.deps.db).audits().get()).docs.map((doc) => doc.data());
    expect(audits.filter((audit) => audit.kind === 'inboxKeyChanged')).toHaveLength(2); // the first publish and the change
    expect(JSON.stringify(audits)).not.toContain(pro.uid);
    expect(JSON.stringify(audits)).not.toContain(next.pub);
  });

  it('does not log or audit when the same key is published again', async () => {
    const before = (await refs(env.deps.db).audits().get()).size;

    await env.call(publishProfile, { profile: mariaProfile(pro.inboxKey) }, who());

    expect((await refs(env.deps.db).audits().get()).size).toBe(before);
  });
});

describe('updateInboxKey (rotation)', () => {
  it('makes the new key current in the ring and on the public page, and retires the old one', async () => {
    const next = newInboxKey();

    const result = (await env.call(updateInboxKey, { inboxKey: next }, who())) as { keyring: { keyId: string; retiredAt?: string }[] };

    expect(result.keyring.map((entry) => entry.keyId)).toEqual([pro.inboxKey.keyId, next.keyId]);
    expect(result.keyring[0]?.retiredAt).toBeDefined();
    expect(((await refs(env.deps.db).profile('maria').get()).data() as PublicProfileDoc).inboxKey.keyId).toBe(next.keyId);
  });

  it('can bring an older key back (restored from the recovery key) without duplicating it', async () => {
    const next = newInboxKey();
    await env.call(updateInboxKey, { inboxKey: next }, who());

    const result = (await env.call(updateInboxKey, { inboxKey: pro.inboxKey }, who())) as { keyring: { keyId: string; retiredAt?: string }[] };

    expect(result.keyring.map((entry) => entry.keyId)).toEqual([pro.inboxKey.keyId, next.keyId]);
    expect(result.keyring.find((entry) => entry.keyId === pro.inboxKey.keyId)?.retiredAt).toBeUndefined();
    expect(result.keyring.find((entry) => entry.keyId === next.keyId)?.retiredAt).toBeDefined();
  });

  it('refuses a key whose id does not match', async () => {
    await expect(env.call(updateInboxKey, { inboxKey: { ...pro.inboxKey, keyId: 'BBBBBBBBBBB' } }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('tells the app until when a retired key still accepts envelopes, and schedules its removal (D51)', async () => {
    const now = env.clock.now();

    const result = (await env.call(updateInboxKey, { inboxKey: newInboxKey() }, who())) as { keyring: { keyId: string; retiredAt?: string; acceptsUntil?: string; compromisedAt?: string }[] };

    expect(result.keyring[0]).toMatchObject({ keyId: pro.inboxKey.keyId, retiredAt: new Date(now).toISOString(), acceptsUntil: new Date(now + DAY).toISOString() });
    expect(result.keyring[0]?.compromisedAt).toBeUndefined();
    expect(result.keyring[1]?.acceptsUntil).toBeUndefined();
    expect((await account()).inboxKeyringPruneAt?.toMillis()).toBe(now + DAY + 30 * DAY);
  });

  it('closes a compromised key at once and never lets it become current again, through either path (D51)', async () => {
    const now = env.clock.now();
    const next = newInboxKey();

    const result = (await env.call(updateInboxKey, { inboxKey: next, compromised: true }, who())) as { keyring: { keyId: string; acceptsUntil?: string; compromisedAt?: string }[] };

    expect(result.keyring[0]).toMatchObject({ keyId: pro.inboxKey.keyId, acceptsUntil: new Date(now).toISOString(), compromisedAt: new Date(now).toISOString() });
    await expect(env.call(updateInboxKey, { inboxKey: pro.inboxKey }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT', details: { fields: ['inboxKey'] } });
    await expect(env.call(publishProfile, { profile: mariaProfile(pro.inboxKey) }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT', details: { fields: ['profile.inboxKey'] } });
    expect((await account()).inboxKeyring.map((entry) => entry.keyId)).toEqual([pro.inboxKey.keyId, next.keyId]);
  });
});

describe('publishAvailability', () => {
  it('stores the rules, drops busy entries that are over and keeps names and reasons out', async () => {
    await env.call(publishAvailability, mariaAvailability({
      busy: [
        { startsAt: '2026-09-01T10:00:00.000Z', endsAt: '2026-09-01T11:00:00.000Z', kind: 'block' },
        { startsAt: '2026-10-05T10:00:00.000Z', endsAt: '2026-10-05T11:00:00.000Z', kind: 'appointment' }
      ]
    }), who());

    const stored = (await refs(env.deps.db).availability(pro.uid).get()).data() as AvailabilityDoc;
    expect(stored.busy).toHaveLength(1);
    expect(stored.busy[0]?.kind).toBe('appointment');
    expect(stored.reminderHourLocal).toBe(18);
    expect(stored.noShow.action).toBe('approveNewBookings');
  });

  it('refuses a reversed stretch, a reversed day off and an unknown field', async () => {
    const bad = mariaAvailability({ weekly: [{ weekday: 3, startMinutes: 600, endMinutes: 500 }] });
    await expect(env.call(publishAvailability, bad, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(publishAvailability, mariaAvailability({ daysOff: [{ startDate: '2026-10-09', endDate: '2026-10-01' }] }), who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(env.call(publishAvailability, { ...mariaAvailability(), clientNames: ['Ana'] }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });
});

describe('portal', () => {
  const token = base64url(Buffer.from('0123456789abcdef'));
  const content = {
    clientName: 'Ana Costa',
    upcoming: [],
    next: { serviceName: 'Brazilian Glow', recommendedDate: '2026-10-28' },
    past: [{ serviceName: 'Glow Facial', date: '2026-09-30', summary: 'Good response' }],
    aftercare: [{ title: 'After your Brazilian Glow', lines: ['Use a gentle cleanser tonight.', 'Wear sunscreen.'], date: '2026-09-30' }],
    products: [{ name: 'Calming serum', note: 'Used in your treatment' }],
    rebook: { serviceId: SERVICE.glowFacial, addOnIds: [], client: { name: 'Ana Costa', phone: '+5511987654321', locale: 'pt-BR' } }
  };
  const publish = (extra: Record<string, unknown> = {}) =>
    env.call(publishPortal, { token, clientRef: randomUUID(), content, ...extra }, who());

  it('shows the client only what the professional published, and stores only the hash of the link', async () => {
    await publish();

    const view = (await env.call(getPortal, { token })) as { clientName: string; aftercare: { lines: string[] }[]; professional: { displayName: string }; rebook?: { serviceId: string }; expiresAt: string };

    expect(view.clientName).toBe('Ana Costa');
    expect(view.aftercare[0]?.lines).toHaveLength(2);
    expect(view.professional.displayName).toBe('Maria Souza');
    expect(view.rebook?.serviceId).toBe(SERVICE.glowFacial);
    expect(JSON.stringify(view)).not.toContain('5511987654321'); // the rebook identity stays on the server
    const portals = await refs(env.deps.db).portals().get();
    expect(portals.docs[0]?.id).toBe(sha256Hex(`portal:${token}`));
    expect(JSON.stringify(portals.docs[0]?.data())).not.toContain(token);
  });

  it('slides the expiry forward on use and lapses after 180 idle days', async () => {
    await publish();
    env.clock.advance(100 * DAY);
    const used = (await env.call(getPortal, { token })) as { expiresAt: string };
    expect(Date.parse(used.expiresAt)).toBe(env.clock.now() + 180 * DAY);

    env.clock.advance(179 * DAY);
    await env.call(getPortal, { token });
    env.clock.advance(181 * DAY);
    await expect(env.call(getPortal, { token })).rejects.toMatchObject({ code: 'TOKEN_EXPIRED' });
  });

  it('is revoked at once, loses its content, and can be published again on purpose', async () => {
    await publish();
    await env.call(publishPortal, { token, clientRef: randomUUID(), revoke: true }, who());

    await expect(env.call(getPortal, { token })).rejects.toMatchObject({ code: 'TOKEN_EXPIRED' });
    const stored = (await refs(env.deps.db).portal(sha256Hex(`portal:${token}`)).get()).data() as PortalDoc;
    expect(stored.content).toEqual({});
    await publish();
    expect(await env.call(getPortal, { token })).toMatchObject({ clientName: 'Ana Costa' });
  });

  it('refuses a guessable token, a token of another professional and a missing body', async () => {
    await expect(env.call(publishPortal, { token: 'a'.repeat(22), clientRef: randomUUID(), content }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await publish();
    const other = await seedProfessional(env, { uid: 'pro-other', slug: 'other-pro' });
    await expect(env.call(publishPortal, { token, clientRef: randomUUID(), content }, ownerContext(other.uid))).rejects.toMatchObject({ code: 'CONFLICT' });
    await expect(env.call(publishPortal, { token: base64url(Buffer.from('fedcba9876543210')), clientRef: randomUUID() }, who())).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('answers NOT_FOUND for an unknown link', async () => {
    await expect(env.call(getPortal, { token: base64url(Buffer.from('nothing-here-abcd')).slice(0, 22) })).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('devices', () => {
  it('registers a token once and removes it on sign-out', async () => {
    const fcmToken = `fcm-${'a'.repeat(60)}`;
    await env.call(registerDevice, { fcmToken, platform: 'ios', locale: 'pt-BR' }, who());
    await env.call(registerDevice, { fcmToken, platform: 'ios', locale: 'pt-BR' }, who());
    expect((await refs(env.deps.db).devices(pro.uid).get()).size).toBe(1);

    await env.call(unregisterDevice, { fcmToken }, who());
    expect((await refs(env.deps.db).devices(pro.uid).get()).size).toBe(0);
  });
});
