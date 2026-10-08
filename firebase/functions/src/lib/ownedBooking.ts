import type { DocumentReference, Firestore } from 'firebase-admin/firestore';

import type { BookingDoc } from './docs.js';
import { AppError } from './errors.js';
import type { Reader } from './store.js';
import { dataOf, refs } from './store.js';

export interface OwnedBooking {
  id: string;
  ref: DocumentReference;
  data: BookingDoc;
}

/** A booking of this professional. Someone else's booking is reported as NOT_FOUND so ids cannot be probed. */
export async function loadOwnedBooking(reader: Reader, db: Firestore, ownerUid: string, bookingId: string): Promise<OwnedBooking> {
  const ref = refs(db).booking(bookingId);
  const data = dataOf<BookingDoc>(await reader.doc(ref));
  if (data?.ownerUid !== ownerUid) throw new AppError('NOT_FOUND');
  return { id: bookingId, ref, data };
}
