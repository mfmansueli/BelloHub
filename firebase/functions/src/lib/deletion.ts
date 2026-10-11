// Cascade deletes (D30, docs/11 section 8). Two entry points: one client's server data, and a whole account. Both are
// idempotent and safe to run again, because a job re-runs an interrupted account deletion.
//
// What they NEVER touch: the registration counter and its ledger when a CLIENT is deleted (deleting never returns a
// free slot, D42). A deleted ACCOUNT removes the ledger with everything else (ASSUMPTION-18: no tombstone is kept).

import type { DocumentReference, Query } from 'firebase-admin/firestore';

import type { Deps } from '../app/Deps.js';
import { recordAudit } from './audit.js';
import type { AccountDoc, BookingDoc, InboxItemDoc } from './docs.js';
import { C } from './docs.js';
import { dataOf, refs, ts } from './store.js';

const BATCH = 400;

export async function deleteRefs(deps: Deps, targets: readonly DocumentReference[]): Promise<number> {
  for (let start = 0; start < targets.length; start += BATCH) {
    const batch = deps.db.batch();
    for (const target of targets.slice(start, start + BATCH)) batch.delete(target);
    await batch.commit();
  }
  return targets.length;
}

async function refsOf(query: Query): Promise<DocumentReference[]> {
  return (await query.get()).docs.map((doc) => doc.ref);
}

export interface ClientDataTarget {
  phoneHash?: string | undefined;
  bookingIds?: readonly string[] | undefined;
  portalClientRef?: string | undefined;
}

export interface ClientDataCounts {
  bookings: number;
  mailboxItems: number;
  requests: number;
  waitlist: number;
  portals: number;
  contacts: number;
}

/**
 * Removes what the server holds about one client of one professional: her bookings, the sealed items tied to them,
 * reschedule requests, waitlist entries, portal and the contact row. Owner-scoped: ids that are not hers are ignored.
 */
export async function deleteClientData(deps: Deps, ownerUid: string, target: ClientDataTarget): Promise<ClientDataCounts> {
  const r = refs(deps.db);
  const counts: ClientDataCounts = { bookings: 0, mailboxItems: 0, requests: 0, waitlist: 0, portals: 0, contacts: 0 };

  const bookingIds = new Set<string>();
  // Her trusted devices (verify-fallback) go too: by the e-mail of any booking removed here, and by her phone.
  const emailHashes = new Set<string>();
  if (target.phoneHash) {
    const found = await r.bookings().where('ownerUid', '==', ownerUid).where('phoneHash', '==', target.phoneHash).get();
    found.docs.forEach((doc) => {
      bookingIds.add(doc.id);
      const emailHash = (doc.data() as BookingDoc).emailHash;
      if (emailHash) emailHashes.add(emailHash);
    });
  }
  for (const id of target.bookingIds ?? []) {
    const doc = await r.booking(id).get();
    const data = doc.data() as BookingDoc | undefined;
    if (doc.exists && data?.ownerUid === ownerUid) {
      bookingIds.add(id);
      if (data.emailHash) emailHashes.add(data.emailHash);
    }
  }
  const devices = r.trustedDevices().where('ownerUid', '==', ownerUid);
  for (const emailHash of emailHashes) {
    await deleteRefs(deps, await refsOf(devices.where('emailHash', '==', emailHash)));
  }
  if (target.phoneHash) await deleteRefs(deps, await refsOf(devices.where('phoneHash', '==', target.phoneHash)));

  for (const id of bookingIds) {
    const items = await r.inboxItems(ownerUid).where('bookingId', '==', id).get();
    for (const item of items.docs) {
      const data = item.data() as InboxItemDoc;
      if (data.storagePath) await deps.blobs.delete(data.storagePath);
      await item.ref.delete();
      counts.mailboxItems += 1;
    }
    const request = await r.rescheduleRequest(id).get();
    if (request.exists) {
      await request.ref.delete();
      counts.requests += 1;
    }
    await deleteRefs(deps, await refsOf(deps.db.collection(C.idempotency).where('bookingId', '==', id)));
    await r.booking(id).delete();
    counts.bookings += 1;
  }

  if (target.phoneHash) {
    counts.waitlist = await deleteRefs(
      deps,
      await refsOf(r.waitlist().where('ownerUid', '==', ownerUid).where('phoneHash', '==', target.phoneHash))
    );
    const contact = r.contact(ownerUid, target.phoneHash);
    if ((await contact.get()).exists) {
      await contact.delete();
      counts.contacts = 1;
    }
  }
  if (target.portalClientRef) {
    counts.portals = await deleteRefs(
      deps,
      await refsOf(r.portals().where('ownerUid', '==', ownerUid).where('clientRef', '==', target.portalClientRef))
    );
  }
  await recordAudit(deps, { kind: 'clientDataDeleted', uid: ownerUid });
  deps.log.info('client.deleted', { ownerUid, bookings: counts.bookings, envelopes: counts.mailboxItems });
  return counts;
}

/**
 * Removes everything under one professional's uid, the account last, and her Auth user. The account document carries
 * `deletion.requestedAt` from the first step, so an interrupted run is found and finished by the cleanup job.
 */
export async function cascadeDeleteAccount(deps: Deps, uid: string): Promise<void> {
  const r = refs(deps.db);
  const db = deps.db;
  const account = dataOf<AccountDoc>(await r.account(uid).get());
  if (account && !account.deletion.requestedAt) {
    await r.account(uid).update({ 'deletion.requestedAt': ts(deps.now()), updatedAt: ts(deps.now()) });
  }

  const byOwner = (collection: string): Query => db.collection(collection).where('ownerUid', '==', uid);
  const slugClaims = await refsOf(byOwner('slugs'));
  const slugNames = new Set<string>(slugClaims.map((ref) => ref.id));
  if (account?.slug) slugNames.add(account.slug);

  // Sealed items first: their Storage objects are listed by prefix as well, so an orphan cannot survive.
  let page: string | undefined;
  do {
    const listed = await deps.blobs.list(`inbox/${uid}/`, page);
    for (const path of listed.paths) await deps.blobs.delete(path);
    page = listed.next;
  } while (page);

  for (const collection of ['bookings', 'holds', 'portal', 'rescheduleRequests', 'waitlist', 'contacts', 'idempotency', 'trustedDevices']) {
    await deleteRefs(deps, await refsOf(byOwner(collection)));
  }
  await deleteRefs(deps, [r.availability(uid), r.intakeForm(uid), r.businessLocation(uid), r.calendarLock(uid)]);
  await deleteRefs(deps, [...slugNames].flatMap((slug) => [r.profile(slug), r.slug(slug)]));
  await db.recursiveDelete(db.collection('inbox').doc(uid));
  await db.recursiveDelete(db.collection('devices').doc(uid));
  await db.recursiveDelete(r.account(uid));

  try {
    await deps.auth.deleteUser(uid);
  } catch (error) {
    if ((error as { code?: unknown }).code !== 'auth/user-not-found') throw error;
  }
  await recordAudit(deps, { kind: 'accountDeleted', uid });
  deps.log.info('account.deleted', { ownerUid: uid });
}
