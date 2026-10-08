import type { DocumentSnapshot, Firestore } from 'firebase-admin/firestore';

import { sha256Hex } from './crypto.js';
import type { HoldDoc } from './docs.js';
import type { Reader } from './store.js';
import { refs } from './store.js';

/** Holds are found by the hash of the secret the browser (or the waitlist link) holds. */
export function holdKeyHash(holdKey: string): string {
  return sha256Hex(`hold:${holdKey}`);
}

export interface FoundHold {
  id: string;
  snapshot: DocumentSnapshot;
  data: HoldDoc;
}

/** The holds of one professional made with this key (a new hold replaces the previous one). */
export async function findHoldsByKey(reader: Reader, db: Firestore, ownerUid: string, holdKey: string): Promise<FoundHold[]> {
  const result = await reader.query(
    refs(db).holds().where('ownerUid', '==', ownerUid).where('holdKeyHash', '==', holdKeyHash(holdKey))
  );
  return result.docs.map((snapshot) => ({ id: snapshot.id, snapshot, data: snapshot.data() as HoldDoc }));
}
