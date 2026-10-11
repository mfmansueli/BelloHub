import type { Firestore } from 'firebase-admin/firestore';

import type { BookingStatus, BusinessLocationDoc, PublicLocation } from './docs.js';
import type { Reader } from './store.js';
import { dataOf, refs } from './store.js';

/**
 * Who may see where she works (owner, 2026-10-11), one rule for every place that shows it: with `public` everybody
 * (it is on her page anyway); with `confirmed`, the default, only a client whose booking is confirmed, so a request
 * still waiting for her never reveals what may be her home. Pure.
 */
export function shownLocation(stored: BusinessLocationDoc | undefined, status: BookingStatus): PublicLocation | undefined {
  if (!stored) return undefined;
  return stored.visibility === 'public' || status === 'confirmed' ? stored.location : undefined;
}

/** Her stored address, read in or out of a transaction. */
export async function loadLocation(db: Firestore, ownerUid: string, reader?: Reader): Promise<BusinessLocationDoc | undefined> {
  const ref = refs(db).businessLocation(ownerUid);
  return dataOf<BusinessLocationDoc>(reader ? await reader.doc(ref) : await ref.get());
}

/** The address on one line, for a calendar entry's LOCATION. */
export function oneLine(location: PublicLocation): string {
  return location.lines.join(', ');
}
