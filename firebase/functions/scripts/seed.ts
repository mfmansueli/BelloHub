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
const intake = {
  formVersion: 1,
  template: {
    questions: [
      { key: 'allergies', type: 'yesNo', required: true, label: { en: 'Any allergies?', 'pt-BR': 'Alguma alergia?' } },
      { key: 'notes', type: 'text', required: false, label: { en: 'Anything else Maria should know?', 'pt-BR': 'Algo mais que a Maria deva saber?' } }
    ]
  },
  consent: {
    en: { textVersion: '2026-10', text: 'I agree that Maria keeps this information to take care of me.' },
    'pt-BR': { textVersion: '2026-10', text: 'Concordo que a Maria guarde estas informações para cuidar de mim.' }
  }
} as const;

await call('ensureAccount', { countryCode: 'BR', locale: 'pt-BR' }, idToken);
await call('claimSlug', { slug: SLUG }, idToken);
await call('publishProfile', { profile: { ...mariaProfile(inboxKey), intake } }, idToken);
await call('publishAvailability', mariaAvailability(), idToken);

process.stdout.write(
  [
    `Seeded the demo professional "${SLUG}" (uid ${UID}) in the emulators.`,
    `  page       POST ${functionsBase}/getPublicPage  {"data":{"slug":"${SLUG}"}}`,
    `  inbox key  ${inboxKey.keyId}  (private seed "bello-hub-demo-inbox-seed-000001", X25519, demo only)`,
    '  phone SMS  the Auth emulator prints each code in its log; email code is always 123456 (emulator hook)',
    ''
  ].join('\n')
);
