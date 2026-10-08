// `contacts/{ownerUid}_{phoneHash}`: what one professional's server record knows about one phone, with no name and no
// content (docs/11 section 2). It answers three questions: is this phone already one of her clients (D42: the same
// phone never counts twice), how many no-shows count against it (D13), and when was a sealed form last sent (the
// 12 month rule). The phone itself is stored only as a keyed hash.

import type { Transaction } from 'firebase-admin/firestore';
import { FieldValue } from 'firebase-admin/firestore';

import type { ContactDoc } from './docs.js';
import type { NoShowMark, NoShowPolicy } from './rules.js';
import { countedNoShows } from './rules.js';
import type { Refs } from './store.js';
import { ms, msOpt, ts } from './store.js';

const MAX_MARKS = 50;

export function emptyContact(ownerUid: string, phoneHash: string, now: number): ContactDoc {
  return {
    ownerUid,
    phoneHash,
    registered: false,
    bookingCount: 0,
    marks: [],
    onlineBookingStopped: false,
    createdAt: ts(now),
    updatedAt: ts(now)
  };
}

export function marksOf(contact: ContactDoc | undefined): NoShowMark[] {
  return (contact?.marks ?? []).map((mark) => ({ id: mark.id, at: ms(mark.at), kind: mark.kind }));
}

/** How many marks count now and whether the professional's limit is reached (D13). */
export function noShowState(
  policy: NoShowPolicy,
  contact: ContactDoc | undefined,
  now: number
): { counted: number; limitReached: boolean } {
  const counted = countedNoShows(policy, marksOf(contact), msOpt(contact?.noShowResetAt), now);
  return { counted, limitReached: policy.isOn && counted >= policy.limit };
}

/** The marks after adding `mark` (same id replaces: idempotent), keeping the latest few. */
export function withMark(marks: ContactDoc['marks'] | undefined, mark: NoShowMark): ContactDoc['marks'] {
  const kept = (marks ?? []).filter((existing) => existing.id !== mark.id);
  return [...kept, { id: mark.id, at: ts(mark.at), kind: mark.kind }].slice(-MAX_MARKS);
}

export function withoutMark(marks: ContactDoc['marks'] | undefined, markId: string): ContactDoc['marks'] {
  return (marks ?? []).filter((existing) => existing.id !== markId);
}

/** Writes the contact: creates it when `existing` is undefined, otherwise merges `patch`. */
export function writeContact(
  tx: Transaction,
  r: Refs,
  ownerUid: string,
  phoneHash: string,
  existing: ContactDoc | undefined,
  patch: Partial<ContactDoc>,
  now: number
): void {
  const ref = r.contact(ownerUid, phoneHash);
  if (existing) {
    tx.update(ref, { ...patch, updatedAt: ts(now) });
  } else {
    tx.set(ref, { ...emptyContact(ownerUid, phoneHash, now), ...patch });
  }
}

/**
 * Counts one new registration (D42): the ledger document (an id and a date, no personal data), then the account
 * counter. Called inside a transaction that already read the account, and always together with the calendar lock so
 * two registrations of one professional never race.
 */
export function writeRegistration(
  tx: Transaction,
  r: Refs,
  ownerUid: string,
  ledgerId: string,
  source: 'app' | 'booking',
  now: number,
  increment = 1
): void {
  tx.set(r.registration(ownerUid, ledgerId), { registeredAt: ts(now), source });
  tx.update(r.account(ownerUid), {
    'registrations.count': FieldValue.increment(increment),
    updatedAt: ts(now)
  });
}
