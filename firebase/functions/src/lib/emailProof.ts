import type { Firestore, Transaction } from 'firebase-admin/firestore';

import { keyedHash, sha256Hex } from './crypto.js';
import type { EmailProofDoc } from './docs.js';
import { AppError } from './errors.js';
import { dataOf, ms, plainReader, refs, ts, txReader } from './store.js';

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
 * Is this a proof the server issued for `email` and still within its life? A plain read, before anything is spent on
 * the call: a made-up proof must not consume the rate allowance of the phone, the address or the professional it names
 * (that would let a stranger lock a client out). Single use is enforced by `useEmailProof` inside the transaction.
 */
export async function peekEmailProof(db: Firestore, pepper: string, proof: string, email: string, now: number): Promise<void> {
  const doc = dataOf<EmailProofDoc>(await plainReader.doc(refs(db).emailProof(proofHash(proof))));
  if (!doc || ms(doc.expiresAt) <= now || doc.emailHash !== emailHashOf(pepper, email)) {
    throw new AppError('VERIFICATION_FAILED');
  }
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
