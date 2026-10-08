import type { Firestore, Transaction } from 'firebase-admin/firestore';

import { keyedHash, sha256Hex } from './crypto.js';
import type { EmailProofDoc } from './docs.js';
import { AppError } from './errors.js';
import { dataOf, ms, refs, ts, txReader } from './store.js';

export function emailHashOf(pepper: string, email: string): string {
  return keyedHash(pepper, 'email', email);
}

export function phoneHashOf(pepper: string, phoneE164: string): string {
  return keyedHash(pepper, 'phone', phoneE164);
}

export function proofHash(proof: string): string {
  return sha256Hex(`proof:${proof}`);
}

/**
 * Checks an email proof inside a transaction and marks it used (single use). The proof must be for this email, unused
 * and unexpired. Call it before any write of the transaction; the mark is written with the others.
 */
export async function useEmailProof(
  tx: Transaction,
  db: Firestore,
  pepper: string,
  proof: string,
  email: string,
  now: number
): Promise<() => void> {
  const ref = refs(db).emailProof(proofHash(proof));
  const doc = dataOf<EmailProofDoc>(await txReader(tx).doc(ref));
  if (!doc || doc.usedAt || ms(doc.expiresAt) <= now || doc.emailHash !== emailHashOf(pepper, email)) {
    throw new AppError('VERIFICATION_FAILED');
  }
  return () => {
    tx.update(ref, { usedAt: ts(now) });
  };
}
