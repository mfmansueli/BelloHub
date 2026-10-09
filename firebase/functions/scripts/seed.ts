// Loads the prototype's demo professional (Maria, design/PROTOTYPE-NOTES.md section 3) into RUNNING emulators, through the
// public API only, so the web app (S9) and the iOS app can be exercised end to end:
//
//   cd firebase && firebase emulators:start --project demo-bellohub      (in one terminal)
//   cd firebase/functions && npm run build && npm run seed               (in another)
//
// It refuses to run against anything but the local emulators. Idempotent: running it again changes nothing.
import { createPrivateKey, createPublicKey } from 'node:crypto';

import { getAuth } from 'firebase-admin/auth';

import { base64url, inboxKeyId } from '../src/lib/crypto.js';
import { adminApp, PROJECT_ID } from '../test/support/emulator.js';
import { mariaAvailability, mariaProfile } from '../test/support/seed.js';

process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
const functionsBase = process.env.FUNCTIONS_BASE ?? `http://127.0.0.1:5001/${PROJECT_ID}/europe-west1`;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;

const local = (url: string): boolean => url.startsWith('http://127.0.0.1') || url.startsWith('http://localhost');
if (!/^(127\.0\.0\.1|localhost)(:\d+)?$/.test(authHost) || !local(functionsBase)) {
  throw new Error('seed.ts only talks to the local emulators');
}

const UID = 'demo-maria';
const SLUG = 'maria';

async function call(name: string, data: unknown, idToken: string): Promise<unknown> {
  const response = await fetch(`${functionsBase}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
    body: JSON.stringify({ data })
  });
  const body = (await response.json()) as { result?: unknown; error?: { message?: string } };
  if (!response.ok) throw new Error(`${name} failed: ${response.status} ${body.error?.message ?? ''}`);
  return body.result;
}

/** A fixed inbox key pair so reruns publish the same key: the demo private seed is 32 bytes of readable text. */
function demoInboxKey(): { keyId: string; alg: 'hpke-v1'; pub: string } {
  const seed = Buffer.from('bello-hub-demo-inbox-seed-000001');
  const pkcs8Prefix = Buffer.from('302e020100300506032b656e04220420', 'hex');
  const privateKey = createPrivateKey({ key: Buffer.concat([pkcs8Prefix, seed]), format: 'der', type: 'pkcs8' });
  const pub = base64url(createPublicKey(privateKey).export({ format: 'der', type: 'spki' }).subarray(-32));
  const keyId = inboxKeyId(pub);
  if (!keyId) throw new Error('bad demo key');
  return { keyId, alg: 'hpke-v1', pub };
}

const auth = getAuth(adminApp());
try {
  await auth.createUser({ uid: UID, phoneNumber: '+5511900000000' });
} catch (error) {
  if ((error as { code?: string }).code !== 'auth/uid-already-exists' && (error as { code?: string }).code !== 'auth/phone-number-already-exists') throw error;
}
const signIn = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=demo`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ token: await auth.createCustomToken(UID), returnSecureToken: true })
});
const { idToken } = (await signIn.json()) as { idToken: string };

const inboxKey = demoInboxKey();
// The same health form the web mock publishes (web/test/mock-server/api.ts), so the page's end-to-end flow answers the
// same questions against the real functions. `audience: 'adult'` questions are not asked for a minor.
const intake = {
  formVersion: 1,
  template: {
    questions: [
      {
        key: 'allergies',
        kind: 'multiChoice',
        label: { en: 'Any allergies?', 'pt-BR': 'Alguma alergia?' },
        options: [
          { value: 'fragrance', label: { en: 'Fragrance', 'pt-BR': 'Fragrância' } },
          { value: 'latex', label: { en: 'Latex', 'pt-BR': 'Látex' } },
          { value: 'nuts', label: { en: 'Nuts', 'pt-BR': 'Castanhas' } },
          { value: 'retinol', label: { en: 'Retinol', 'pt-BR': 'Retinol' } },
          { value: 'acids', label: { en: 'Acids', 'pt-BR': 'Ácidos' } },
          { value: 'none', label: { en: 'None', 'pt-BR': 'Nenhuma' } }
        ],
        required: true
      },
      { key: 'medication', kind: 'yesNo', label: { en: 'Do you take any regular medication?', 'pt-BR': 'Você usa algum medicamento regularmente?' }, required: true },
      { key: 'pregnant', kind: 'yesNo', label: { en: 'Are you pregnant or breastfeeding?', 'pt-BR': 'Você está grávida ou amamentando?' }, required: true, audience: 'adult' },
      { key: 'skinCondition', kind: 'yesNo', label: { en: 'Do you have a skin condition, such as eczema or rosacea?', 'pt-BR': 'Você tem alguma condição de pele, como eczema ou rosácea?' }, required: true },
      { key: 'isotretinoin', kind: 'yesNo', label: { en: 'Have you taken isotretinoin or had a peel in the last 6 months?', 'pt-BR': 'Usou isotretinoína ou fez peeling nos últimos 6 meses?' }, required: true },
      {
        key: 'anythingElse',
        kind: 'text',
        label: { en: 'Anything else Maria should know?', 'pt-BR': 'Algo mais que a Maria deva saber?' },
        hint: { en: 'Optional. Skin that reacts easily, products you avoid, a recent procedure.' }
      }
    ]
  }
} as const;

await call('ensureAccount', { countryCode: 'BR', locale: 'pt-BR' }, idToken);
await call('claimSlug', { slug: SLUG }, idToken);
await call('publishProfile', { profile: { ...mariaProfile(inboxKey), intake } }, idToken);
await call('publishAvailability', mariaAvailability(), idToken);
// With a device registered the emulator's push sender records every push in `emulatorOutbox` (scripts/e2e-local.sh waits
// on them). The token is any string of 20+ characters: the emulator never talks to FCM.
const deviceToken = process.env.SEED_DEVICE_TOKEN;
if (deviceToken) await call('registerDevice', { fcmToken: deviceToken, platform: 'ios', locale: 'pt-BR' }, idToken);

process.stdout.write(
  [
    `Seeded the demo professional "${SLUG}" (uid ${UID}) in the emulators.`,
    `  page       POST ${functionsBase}/getPublicPage  {"data":{"slug":"${SLUG}"}}`,
    `  inbox key  ${inboxKey.keyId}  (private seed "bello-hub-demo-inbox-seed-000001", X25519, demo only)`,
    '  phone SMS  the Auth emulator prints each code in its log; email code is always 123456 (emulator hook)',
    ...(deviceToken ? ['  device     one iPhone registered, so pushes show up in emulatorOutbox'] : []),
    ''
  ].join('\n')
);
