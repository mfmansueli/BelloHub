// Trusted devices: a returning client skips the e-mail code (verify-fallback item 2). After a booking confirmed with a
// fresh e-mail proof, the server hands the browser an opaque token for THIS page and THIS e-mail; the next booking
// with the same e-mail on the same page may show the token instead of a new proof. Only the token's SHA-256 is stored,
// the token lives 90 days and is never renewed, at most five live per e-mail and page (a sixth replaces the oldest).
//
// The token proves only "this browser verified this address on this page before". It never opens a booking (that is
// the manage token), and createBooking refuses it whenever the booking would not be confirmed at once (approval, the
// no-show limit): those cases always go back to the code.

import type { Firestore, Transaction } from 'firebase-admin/firestore';

import type { Deps } from '../app/Deps.js';
import { MAX_TRUSTED_DEVICES, TRUSTED_DEVICE_DAYS } from '../config/limits.js';
import { sha256Hex } from './crypto.js';
import type { TrustedDeviceDoc } from './docs.js';
import { emailHashOf } from './emailProof.js';
import { AppError } from './errors.js';
import { dataOf, ms, plainReader, refs, ts, txReader } from './store.js';

const DAY_MS = 86_400_000;

export function deviceTokenHash(token: string): string {
  return sha256Hex(`device:${token}`);
}

/** Valid for this page and this address and not expired; anything else is VERIFICATION_FAILED (same answer for all). */
function isValidFor(doc: TrustedDeviceDoc | undefined, slug: string, emailHash: string, now: number): doc is TrustedDeviceDoc {
  return !!doc && doc.slug === slug && doc.emailHash === emailHash && ms(doc.expiresAt) > now;
}

/** A plain read before any rate allowance is spent (like `peekEmailProof`): a made-up token costs only the caller. */
export async function peekTrustedDevice(
  db: Firestore,
  pepper: string,
  token: string,
  slug: string,
  email: string,
  now: number
): Promise<void> {
  const doc = dataOf<TrustedDeviceDoc>(await plainReader.doc(refs(db).trustedDevice(deviceTokenHash(token))));
  if (!isValidFor(doc, slug, emailHashOf(pepper, email), now)) throw new AppError('VERIFICATION_FAILED');
}

/** Checks the token inside the booking transaction; the returned function records its use with the other writes. */
export async function useTrustedDevice(
  tx: Transaction,
  db: Firestore,
  pepper: string,
  token: string,
  slug: string,
  email: string,
  now: number
): Promise<() => void> {
  const ref = refs(db).trustedDevice(deviceTokenHash(token));
  const doc = dataOf<TrustedDeviceDoc>(await txReader(tx).doc(ref));
  if (!isValidFor(doc, slug, emailHashOf(pepper, email), now)) throw new AppError('VERIFICATION_FAILED');
  return () => {
    tx.update(ref, { lastUsedAt: ts(now) });
  };
}

export interface IssuedDevice {
  token: string;
  expiresAt: number;
}

/**
 * Issues a token after a confirmed, code-verified booking. Outside the booking transaction on purpose: a failure here
 * must not undo a booking, so it is logged and the page simply asks for a code next time.
 */
export async function issueTrustedDevice(
  deps: Deps,
  input: { ownerUid: string; slug: string; email: string; phoneHash: string }
): Promise<IssuedDevice | undefined> {
  try {
    const r = refs(deps.db);
    const now = deps.now();
    const emailHash = emailHashOf(deps.pepper, input.email);
    const existing = await r.trustedDevices().where('slug', '==', input.slug).where('emailHash', '==', emailHash).get();
    // Oldest first; keep MAX - 1 so the new one makes MAX.
    const ordered = existing.docs.sort(
      (a, b) => ms((a.data() as TrustedDeviceDoc).createdAt) - ms((b.data() as TrustedDeviceDoc).createdAt)
    );
    const surplus = ordered.slice(0, Math.max(0, ordered.length - (MAX_TRUSTED_DEVICES - 1)));
    const token = deps.random.token();
    const expiresAt = now + TRUSTED_DEVICE_DAYS * DAY_MS;
    const batch = deps.db.batch();
    for (const doc of surplus) batch.delete(doc.ref);
    batch.create(r.trustedDevice(deviceTokenHash(token)), {
      ownerUid: input.ownerUid,
      slug: input.slug,
      emailHash,
      phoneHash: input.phoneHash,
      createdAt: ts(now),
      expiresAt: ts(expiresAt)
    } satisfies TrustedDeviceDoc);
    await batch.commit();
    return { token, expiresAt };
  } catch {
    deps.log.warn('device.issueFailed', { ownerUid: input.ownerUid });
    return undefined;
  }
}

/** "Forget this device": removes the token if it exists. Says nothing about whether it did. */
export async function revokeTrustedDevice(deps: Deps, token: string): Promise<void> {
  await refs(deps.db).trustedDevice(deviceTokenHash(token)).delete();
}
