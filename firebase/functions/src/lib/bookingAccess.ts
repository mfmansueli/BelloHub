import type { DocumentReference, Firestore } from 'firebase-admin/firestore';

import { MAX_MANAGE_TOKENS_PER_BOOKING } from '../config/limits.js';
import { sha256Hex } from './crypto.js';
import type { BookingDoc } from './docs.js';
import { AppError } from './errors.js';
import type { Reader } from './store.js';
import { ms, refs } from './store.js';

export interface TokenBooking {
  id: string;
  ref: DocumentReference;
  data: BookingDoc;
}

export function tokenHash(token: string): string {
  return sha256Hex(`manage:${token}`);
}

/**
 * The booking a manage token opens (docs/06 section 5): the token's SHA-256 is looked up, the token itself is never
 * stored. Valid until the visit ends + 7 days (`purgeAt`), after which the booking is gone anyway.
 * Unknown tokens are NOT_FOUND; a known one past its time is TOKEN_EXPIRED.
 */
export async function findBookingByToken(reader: Reader, db: Firestore, token: string, now: number): Promise<TokenBooking> {
  const result = await reader.query(
    refs(db).bookings().where('manageTokenHashes', 'array-contains', tokenHash(token)).limit(1)
  );
  const snapshot = result.docs[0];
  if (!snapshot) throw new AppError('NOT_FOUND');
  const data = snapshot.data() as BookingDoc;
  if (now >= ms(data.purgeAt)) throw new AppError('TOKEN_EXPIRED');
  return { id: snapshot.id, ref: snapshot.ref, data };
}

/** The hashes after adding one: at most five tokens stay valid, the oldest is dropped (findBookings mints more). */
export function withNewTokenHash(hashes: readonly string[], newHash: string): string[] {
  return [...hashes, newHash].slice(-MAX_MANAGE_TOKENS_PER_BOOKING);
}
