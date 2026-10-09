import type { Firestore, Transaction } from 'firebase-admin/firestore';

import { AppError } from './errors.js';

const MAX_ATTEMPTS = 25;

function isContention(error: unknown): boolean {
  if (typeof error !== 'object' || error === null) return false;
  const code = (error as { code?: unknown }).code;
  return code === 10 || code === 'aborted' || code === 'ABORTED';
}

/**
 * A transaction that retries on contention more patiently than the default (a viral booking link makes many callers
 * queue behind one professional's calendar lock) and, if it still cannot get through, tells the caller to try again
 * instead of leaking an SDK error.
 */
export async function runTransaction<T>(db: Firestore, update: (tx: Transaction) => Promise<T>): Promise<T> {
  try {
    return await db.runTransaction(update, { maxAttempts: MAX_ATTEMPTS });
  } catch (error) {
    if (isContention(error)) throw new AppError('TRY_AGAIN');
    throw error;
  }
}
