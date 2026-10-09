// The professional's inbox key ring (docs/06 section 3.2, D51): the current public key plus retired ones. A retired
// key keeps accepting NEW envelopes for a grace period (a form that was already open finishes), then only the current
// key does; a rotation marked as a compromise closes the old key at once. Retired entries stay in the ring until no
// envelope can reference them any more, so the app knows which private key generations it still needs.

import type { Timestamp } from 'firebase-admin/firestore';

import type { InboxKeyringEntry } from './docs.js';
import { ENVELOPE_TTL_DAYS } from './rules.js';
import { ms, ts } from './store.js';

/** How long a retired key still accepts new envelopes (D51). */
export const KEY_GRACE_MS = 24 * 3_600_000;
const ENVELOPE_TTL_MS = ENVELOPE_TTL_DAYS * 86_400_000;

export interface KeyApplied {
  keyring: InboxKeyringEntry[];
  /** The current key changed (a new key, or an older one made current again). */
  changed: boolean;
}

export function currentKey(keyring: readonly InboxKeyringEntry[]): InboxKeyringEntry | undefined {
  return keyring.filter((entry) => !entry.retiredAt).at(-1);
}

/** The last instant a retired entry accepts a new envelope: at once when compromised, else `retiredAt` + grace. */
export function acceptsUntil(entry: InboxKeyringEntry): number | undefined {
  if (!entry.retiredAt) return undefined;
  return entry.compromisedAt ? ms(entry.retiredAt) : ms(entry.retiredAt) + KEY_GRACE_MS;
}

/** May an envelope for `keyId` be accepted at `now`? */
export function acceptsKey(keyring: readonly InboxKeyringEntry[], keyId: string, now: number): boolean {
  const entry = keyring.find((candidate) => candidate.keyId === keyId);
  if (!entry) return false;
  const until = acceptsUntil(entry);
  return until === undefined || now < until;
}

/** The entry was retired and every envelope it could still have received has expired: nothing can need it. */
export function isDead(entry: InboxKeyringEntry, now: number): boolean {
  const until = acceptsUntil(entry);
  return until !== undefined && until + ENVELOPE_TTL_MS <= now;
}

/** When the cleanup job should next look at this ring (the earliest death among retired entries), or none. */
export function nextPruneAt(keyring: readonly InboxKeyringEntry[]): number | undefined {
  const deaths = keyring.map(acceptsUntil).filter((until): until is number => until !== undefined);
  return deaths.length === 0 ? undefined : Math.min(...deaths) + ENVELOPE_TTL_MS;
}

export function pruneKeyring(keyring: readonly InboxKeyringEntry[], now: number): InboxKeyringEntry[] {
  return keyring.filter((entry) => !isDead(entry, now));
}

export interface ApplyOptions {
  /** D51: the key being replaced was exposed; it stops accepting envelopes at once and can never be current again. */
  compromised?: boolean | undefined;
}

export type ApplyFailure = 'compromisedKey';

/**
 * Makes `key` the current one. The same key again changes nothing. Dead entries are dropped on the way. Returns a
 * failure (no ring) when the key was marked compromised earlier: a stolen key must not come back.
 */
export function applyInboxKey(
  keyring: readonly InboxKeyringEntry[],
  key: { keyId: string; pub: string },
  now: number,
  options: ApplyOptions = {}
): KeyApplied | { failure: ApplyFailure } {
  const live = pruneKeyring(keyring, now);
  const current = currentKey(live);
  if (current?.keyId === key.keyId) return { keyring: live, changed: false };

  const existing = live.find((entry) => entry.keyId === key.keyId);
  if (existing?.compromisedAt) return { failure: 'compromisedKey' };

  const retired = live.map((entry) =>
    entry.retiredAt
      ? entry
      : { ...entry, retiredAt: ts(now), ...(options.compromised ? { compromisedAt: ts(now) } : {}) }
  );
  if (existing) {
    // An older key becomes current again (restored from the recovery key): keep its original date, clear the retirement.
    const { retiredAt: _retiredAt, ...reactivated } = existing;
    return { keyring: retired.map((entry) => (entry.keyId === existing.keyId ? reactivated : entry)), changed: true };
  }
  return { keyring: [...retired, { keyId: key.keyId, pub: key.pub, createdAt: ts(now) }], changed: true };
}

export function isKnownKey(keyring: readonly InboxKeyringEntry[], keyId: string): boolean {
  return keyring.some((entry) => entry.keyId === keyId);
}

export interface KeyringViewEntry {
  keyId: string;
  createdAt: Timestamp;
  retiredAt?: Timestamp;
  acceptsUntil?: Timestamp;
  compromisedAt?: Timestamp;
}

export function keyringView(keyring: readonly InboxKeyringEntry[]): KeyringViewEntry[] {
  return keyring.map((entry) => {
    const until = acceptsUntil(entry);
    return {
      keyId: entry.keyId,
      createdAt: entry.createdAt,
      ...(entry.retiredAt ? { retiredAt: entry.retiredAt } : {}),
      ...(until !== undefined ? { acceptsUntil: ts(until) } : {}),
      ...(entry.compromisedAt ? { compromisedAt: entry.compromisedAt } : {})
    };
  });
}
