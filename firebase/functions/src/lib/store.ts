// Typed access to the collections and one reader abstraction, so the same read code runs inside a transaction (where
// the reads become part of its lock) and outside it.

import type { DocumentReference, DocumentSnapshot, Firestore, Query, QuerySnapshot, Transaction } from 'firebase-admin/firestore';
import { Timestamp } from 'firebase-admin/firestore';

import { C } from './docs.js';

export function refs(db: Firestore) {
  return {
    account: (uid: string) => db.collection(C.accounts).doc(uid),
    registrations: (uid: string) => db.collection(C.accounts).doc(uid).collection(C.registrations),
    registration: (uid: string, id: string) => db.collection(C.accounts).doc(uid).collection(C.registrations).doc(id),
    slug: (slug: string) => db.collection(C.slugs).doc(slug),
    profile: (slug: string) => db.collection(C.publicProfiles).doc(slug),
    intakeForm: (uid: string) => db.collection(C.intakeForms).doc(uid),
    availability: (uid: string) => db.collection(C.availability).doc(uid),
    bookings: () => db.collection(C.bookings),
    booking: (id: string) => db.collection(C.bookings).doc(id),
    holds: () => db.collection(C.holds),
    hold: (id: string) => db.collection(C.holds).doc(id),
    inboxItems: (uid: string) => db.collection(C.inbox).doc(uid).collection(C.items),
    inboxItem: (uid: string, id: string) => db.collection(C.inbox).doc(uid).collection(C.items).doc(id),
    portals: () => db.collection(C.portal),
    portal: (tokenHash: string) => db.collection(C.portal).doc(tokenHash),
    rescheduleRequests: () => db.collection(C.rescheduleRequests),
    rescheduleRequest: (id: string) => db.collection(C.rescheduleRequests).doc(id),
    waitlist: () => db.collection(C.waitlist),
    waitlistEntry: (id: string) => db.collection(C.waitlist).doc(id),
    contact: (ownerUid: string, phoneHash: string) => db.collection(C.contacts).doc(`${ownerUid}_${phoneHash}`),
    contacts: () => db.collection(C.contacts),
    devices: (uid: string) => db.collection(C.devices).doc(uid).collection(C.tokens),
    device: (uid: string, id: string) => db.collection(C.devices).doc(uid).collection(C.tokens).doc(id),
    calendarLock: (uid: string) => db.collection(C.calendarLocks).doc(uid),
    emailCode: (emailHash: string) => db.collection(C.emailCodes).doc(emailHash),
    emailProof: (proofHash: string) => db.collection(C.emailProofs).doc(proofHash),
    trustedDevices: () => db.collection(C.trustedDevices),
    trustedDevice: (tokenHash: string) => db.collection(C.trustedDevices).doc(tokenHash),
    idempotency: (keyHash: string) => db.collection(C.idempotency).doc(keyHash),
    rate: (key: string) => db.collection(C.rate).doc(key),
    audits: () => db.collection(C.audit)
  };
}

export type Refs = ReturnType<typeof refs>;

/** Reads that work the same in and out of a transaction. */
export interface Reader {
  doc(ref: DocumentReference): Promise<DocumentSnapshot>;
  query(query: Query): Promise<QuerySnapshot>;
}

export const plainReader: Reader = {
  doc: (ref) => ref.get(),
  query: (query) => query.get()
};

export function txReader(tx: Transaction): Reader {
  return {
    doc: (ref) => tx.get(ref),
    query: (query) => tx.get(query)
  };
}

/**
 * The data of an existing document, typed by the caller; undefined when it does not exist. Firestore returns untyped
 * data, so the caller names the stored shape (src/lib/docs.ts); the type parameter is the point of the function.
 */
// eslint-disable-next-line @typescript-eslint/no-unnecessary-type-parameters
export function dataOf<T>(snapshot: DocumentSnapshot): T | undefined {
  return snapshot.exists ? (snapshot.data() as T) : undefined;
}

export function ms(timestamp: Timestamp): number {
  return timestamp.toMillis();
}

export function ts(epochMs: number): Timestamp {
  return Timestamp.fromMillis(epochMs);
}

export function msOpt(timestamp: Timestamp | undefined): number | undefined {
  return timestamp?.toMillis();
}
