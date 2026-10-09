// The professional's inbox key ring (docs/06 section 3.2): the current public key plus retired ones. Old keys stay so
// envelopes that arrived before a rotation can still be opened; a sealed item is accepted only for a key in the ring.

import type { Timestamp } from 'firebase-admin/firestore';

import type { InboxKeyringEntry } from './docs.js';
import { ts } from './store.js';

export interface KeyApplied {
  keyring: InboxKeyringEntry[];
  /** The current key changed (a new key, or an older one made current again). */
  changed: boolean;
}

export function currentKey(keyring: readonly InboxKeyringEntry[]): InboxKeyringEntry | undefined {
  return keyring.filter((entry) => !entry.retiredAt).at(-1);
}

/** Makes `key` the current one. The same key again changes nothing. */
export function applyInboxKey(keyring: readonly InboxKeyringEntry[], key: { keyId: string; pub: string }, now: number): KeyApplied {
  const current = currentKey(keyring);
  if (current?.keyId === key.keyId) return { keyring: [...keyring], changed: false };

  const retired = keyring.map((entry) => (entry.retiredAt ? entry : { ...entry, retiredAt: ts(now) }));
  const existing = retired.find((entry) => entry.keyId === key.keyId);
  if (existing) {
    // An older key becomes current again (restored from the recovery key): keep its original date, clear the retirement.
    const { retiredAt: _retiredAt, ...reactivated } = existing;
    return { keyring: retired.map((entry) => (entry === existing ? reactivated : entry)), changed: true };
  }
  return { keyring: [...retired, { keyId: key.keyId, pub: key.pub, createdAt: ts(now) }], changed: true };
}

export function isKnownKey(keyring: readonly InboxKeyringEntry[], keyId: string): boolean {
  return keyring.some((entry) => entry.keyId === keyId);
}

export function keyringView(keyring: readonly InboxKeyringEntry[]): { keyId: string; createdAt: Timestamp; retiredAt?: Timestamp }[] {
  return keyring.map((entry) => ({
    keyId: entry.keyId,
    createdAt: entry.createdAt,
    ...(entry.retiredAt ? { retiredAt: entry.retiredAt } : {})
  }));
}
