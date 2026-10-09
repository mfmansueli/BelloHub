import { EventEmitter } from 'node:events';

import type { App } from 'firebase-admin/app';
import { getApps, initializeApp } from 'firebase-admin/app';
import type { Firestore } from 'firebase-admin/firestore';
import { getFirestore } from 'firebase-admin/firestore';

export const PROJECT_ID = 'demo-bellohub';
export const STORAGE_BUCKET = 'demo-bellohub.appspot.com';

// Tests talk to the emulators only. With no credentials the SDK would probe Google's metadata server for a while
// before giving up; telling it there is none keeps the output clean.
process.env.METADATA_SERVER_DETECTION = 'none';
// The Storage client adds a listener per upload to a shared stream; many uploads in one test run are normal.
EventEmitter.defaultMaxListeners = 50;

export function adminApp(): App {
  const existing = getApps().find((app) => app.name === 'tests');
  return existing ?? initializeApp({ projectId: PROJECT_ID, storageBucket: STORAGE_BUCKET }, 'tests');
}

export function testFirestore(): Firestore {
  const db = getFirestore(adminApp());
  try {
    db.settings({ ignoreUndefinedProperties: true });
  } catch {
    // Settings can be applied once per instance.
  }
  return db;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set: run the tests through firebase emulators:exec (scripts/test-firebase.sh)`);
  return value;
}

/** Empties Firestore between tests (the emulator's own REST endpoint). */
export async function clearFirestore(): Promise<void> {
  const host = requireEnv('FIRESTORE_EMULATOR_HOST');
  const response = await fetch(`http://${host}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, { method: 'DELETE' });
  if (!response.ok) throw new Error(`could not clear Firestore: ${response.status}`);
}

/** Removes every Auth user between tests. */
export async function clearAuth(): Promise<void> {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!host) return;
  const response = await fetch(`http://${host}/emulator/v1/projects/${PROJECT_ID}/accounts`, { method: 'DELETE' });
  if (!response.ok) throw new Error(`could not clear Auth: ${response.status}`);
}
