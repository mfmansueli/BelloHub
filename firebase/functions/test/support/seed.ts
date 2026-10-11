import { generateKeyPairSync } from 'node:crypto';

import type { DocumentData } from 'firebase-admin/firestore';

import type { PublicProfileInput } from '../../src/contracts/profile.js';
import type { AvailabilityInput } from '../../src/contracts/profile.js';
import { base64url, inboxKeyId } from '../../src/lib/crypto.js';
import { ensureAccount } from '../../src/owner/ensureAccount.js';
import { claimSlug } from '../../src/owner/claimSlug.js';
import { publishAvailability } from '../../src/owner/publishAvailability.js';
import { publishProfile } from '../../src/owner/publishProfile.js';
import type { TestEnv } from './env.js';

// Maria's world from design/PROTOTYPE-NOTES.md: an esthetician in Sao Paulo, Tuesday to Saturday 09:00-19:00, lunch
// 12:30-13:30, a 15 minute buffer, two hours of notice, a 60 day window.

export const SERVICE = {
  glowFacial: '11111111-1111-4111-8111-111111111111',
  brazilianGlow: '22222222-2222-4222-8222-222222222222',
  deepCleansing: '33333333-3333-4333-8333-333333333333'
} as const;

export const ADDON = { mask: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' } as const;

export interface Professional {
  uid: string;
  slug: string;
  inboxKey: { keyId: string; alg: 'hpke-v1'; pub: string };
}

export function newInboxKey(): Professional['inboxKey'] {
  const { publicKey } = generateKeyPairSync('x25519');
  const raw = publicKey.export({ format: 'der', type: 'spki' }).subarray(-32);
  const pub = base64url(raw);
  const keyId = inboxKeyId(pub);
  if (!keyId) throw new Error('bad key');
  return { keyId, alg: 'hpke-v1', pub };
}

export function mariaProfile(inboxKey: Professional['inboxKey'], overrides: Partial<PublicProfileInput> = {}): PublicProfileInput {
  return {
    displayName: 'Maria Souza',
    businessName: 'Maria Beauty',
    bio: 'Esthetician in Sao Paulo.',
    city: 'Sao Paulo',
    regionCode: 'BR',
    timeZoneID: 'America/Sao_Paulo',
    currencyCode: 'BRL',
    locales: ['pt-BR', 'en'],
    whatsappE164: '+5511900000000',
    credentials: [{ title: 'Aesthetics technical course', institution: 'Senac SP', year: 2019 }],
    services: [
      { id: SERVICE.glowFacial, name: 'Glow Facial', durationMinutes: 60, price: { display: 'show', amount: 120 } },
      { id: SERVICE.brazilianGlow, name: 'Brazilian Glow', durationMinutes: 90 },
      { id: SERVICE.deepCleansing, name: 'Deep Cleansing', durationMinutes: 75 }
    ],
    addOns: [{ id: ADDON.mask, name: 'Hydration mask', minutes: 15 }],
    booking: { acceptingBookings: true, requiresApproval: false, maxGuests: 2, maxDaysAhead: 60 },
    policy: {
      freeWindowHours: 24,
      clientCanReschedule: true,
      maxReschedules: 2,
      afterWindowCancel: 'allow',
      afterWindowReschedule: 'request',
      askConfirmation: true,
      graceMinutes: 15
    },
    rulesText: { 'pt-BR': 'Alteracoes gratis ate 24 horas antes.', en: 'Changes are free up to 24 hours before.' },
    inboxKey,
    ...overrides
  };
}

export function mariaAvailability(overrides: Partial<AvailabilityInput> = {}): AvailabilityInput {
  return {
    timeZoneID: 'America/Sao_Paulo',
    weekly: [3, 4, 5, 6, 7].map((weekday) => ({ weekday, startMinutes: 9 * 60, endMinutes: 19 * 60 })),
    breaks: [{ startMinutes: 12 * 60 + 30, endMinutes: 13 * 60 + 30 }],
    daysOff: [],
    bufferMinutes: 15,
    minNoticeHours: 2,
    maxDaysAhead: 60,
    busy: [],
    noShow: { isOn: true, limit: 3, action: 'approveNewBookings', lateCancelCounts: false, countingMonths: 12 },
    ...overrides
  };
}

export const ownerContext = (uid: string, authPhone = '+5511900000000') => ({ uid, authPhone });

export interface SeedOptions {
  uid?: string;
  slug?: string;
  profile?: Partial<PublicProfileInput>;
  availability?: Partial<AvailabilityInput>;
}

/** Signs a professional up through the real use cases: account, address, page and availability. */
export async function seedProfessional(env: TestEnv, options: SeedOptions = {}): Promise<Professional> {
  const uid = options.uid ?? 'pro-maria';
  const slug = options.slug ?? 'maria';
  const inboxKey = newInboxKey();
  const who = ownerContext(uid);
  await env.call(ensureAccount, { countryCode: 'BR', locale: 'pt-BR' }, who);
  await env.call(claimSlug, { slug }, who);
  await env.call(publishProfile, { profile: mariaProfile(inboxKey, options.profile) }, who);
  await env.call(publishAvailability, mariaAvailability(options.availability), who);
  return { uid, slug, inboxKey };
}

/** Publishes Maria's page again with a health form, as the app does when she turns the online form on. */
export async function publishProfileWithIntake(env: TestEnv, pro: Professional): Promise<void> {
  await env.call(
    publishProfile,
    {
      profile: {
        ...mariaProfile(pro.inboxKey),
        intake: {
          formVersion: 2,
          template: { questions: [{ key: 'allergies', required: true }] }
        }
      }
    },
    ownerContext(pro.uid)
  );
}

/** A seeded professional's documents, kept in memory so each test can restore them in milliseconds. */
export interface World {
  pro: Professional;
  docs: { path: string; data: DocumentData }[];
}

const WORLD_COLLECTIONS = ['accounts', 'slugs', 'publicProfiles', 'availability', 'intakeForms'] as const;

/** Reads back what `seedProfessional` wrote (rate counters and audit rows are left out on purpose). */
export async function captureWorld(env: TestEnv, pro: Professional): Promise<World> {
  const docs: World['docs'] = [];
  for (const collection of WORLD_COLLECTIONS) {
    const snapshot = await env.deps.db.collection(collection).get();
    snapshot.docs.forEach((doc) => docs.push({ path: doc.ref.path, data: doc.data() }));
  }
  return { pro, docs };
}

/** Puts a captured world into an emptied emulator. */
export async function restoreWorld(env: TestEnv, world: World): Promise<void> {
  const batch = env.deps.db.batch();
  for (const doc of world.docs) batch.set(env.deps.db.doc(doc.path), doc.data);
  await batch.commit();
}

/** The 15:00 Brazilian start of a given day, as an instant: Friday 2026-10-02 at 10:00 in Sao Paulo is 13:00Z. */
export const at = (isoUtc: string): number => Date.parse(isoUtc);

/** Friday 2026-10-02 10:00 in Sao Paulo (a working day, a day after "today"). */
export const FRIDAY_10 = '2026-10-02T13:00:00.000Z';
