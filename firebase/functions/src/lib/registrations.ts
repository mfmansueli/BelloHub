// The D42 counter, in one place. The server is the authority: the count lives in `accounts/{uid}.registrations.count`,
// is only ever incremented, and is only written by functions. Deleting a client never touches it.
//
// A client is counted at most once, however she arrives:
//  - the same client id again (ledger document `accounts/{uid}/registrations/{clientId}`), or
//  - the same phone again (a booking from the link registered it, or an earlier client id did).

import type { Transaction } from 'firebase-admin/firestore';
import { FieldValue } from 'firebase-admin/firestore';

import type { Deps } from '../app/Deps.js';
import { writeContact } from './contacts.js';
import type { AccountDoc, ContactDoc, RegistrationDoc } from './docs.js';
import { phoneHashOf } from './emailProof.js';
import { isPlanActive, registrationDecision } from './rules.js';
import type { Reader } from './store.js';
import { dataOf, msOpt, refs, ts } from './store.js';

export interface RegistrationRequest {
  clientId: string;
  phone?: string | undefined;
}

export interface RegistrationResult {
  clientId: string;
  decision: 'allowed' | 'needsSubscription';
  alreadyCounted: boolean;
}

/** The state read before any write: the ledger entry and the contact of each request. */
export interface RegistrationReads {
  ledger: Map<string, RegistrationDoc | undefined>;
  contacts: Map<string, ContactDoc | undefined>;
}

export async function readRegistrationState(
  reader: Reader,
  deps: Deps,
  ownerUid: string,
  requests: readonly RegistrationRequest[]
): Promise<RegistrationReads> {
  const r = refs(deps.db);
  const ledger = new Map<string, RegistrationDoc | undefined>();
  const contacts = new Map<string, ContactDoc | undefined>();
  await Promise.all(
    requests.map(async (request) => {
      ledger.set(request.clientId, dataOf<RegistrationDoc>(await reader.doc(r.registration(ownerUid, request.clientId))));
      if (request.phone) {
        const hash = phoneHashOf(deps.pepper, request.phone);
        if (!contacts.has(hash)) contacts.set(hash, dataOf<ContactDoc>(await reader.doc(r.contact(ownerUid, hash))));
      }
    })
  );
  return { ledger, contacts };
}

/**
 * Decides and writes the registrations of `requests`, in order. Returns what to answer and the new count. Must run in a
 * transaction that has read the calendar lock and the account (`account`) and will bump the lock.
 */
export function applyRegistrations(
  tx: Transaction,
  deps: Deps,
  ownerUid: string,
  account: AccountDoc,
  reads: RegistrationReads,
  requests: readonly RegistrationRequest[]
): { results: RegistrationResult[]; count: number } {
  const now = deps.now();
  const r = refs(deps.db);
  const planActive = isPlanActive({ state: account.plan.state, expiresAt: msOpt(account.plan.expiresAt) }, now);
  let count = account.registrations.count;
  let added = 0;
  const countedIds = new Set<string>();
  const countedPhones = new Set<string>();
  const results: RegistrationResult[] = [];

  for (const request of requests) {
    const hash = request.phone ? phoneHashOf(deps.pepper, request.phone) : undefined;
    const contact = hash ? reads.contacts.get(hash) : undefined;
    const phoneKnown = hash !== undefined && (contact?.registered === true || countedPhones.has(hash));

    if (reads.ledger.get(request.clientId) || countedIds.has(request.clientId)) {
      results.push({ clientId: request.clientId, decision: 'allowed', alreadyCounted: true });
    } else if (phoneKnown) {
      // The phone was counted already: remember the client id so a retry stays idempotent, and do not count again.
      tx.set(r.registration(ownerUid, request.clientId), { registeredAt: ts(now), source: 'alias' } satisfies RegistrationDoc);
      countedIds.add(request.clientId);
      results.push({ clientId: request.clientId, decision: 'allowed', alreadyCounted: true });
    } else if (registrationDecision(count, planActive) === 'allowed') {
      tx.set(r.registration(ownerUid, request.clientId), { registeredAt: ts(now), source: 'app' } satisfies RegistrationDoc);
      if (hash) {
        writeContact(tx, r, ownerUid, hash, contact, { registered: true, registrationId: request.clientId }, now);
        countedPhones.add(hash);
      }
      countedIds.add(request.clientId);
      count += 1;
      added += 1;
      results.push({ clientId: request.clientId, decision: 'allowed', alreadyCounted: false });
    } else {
      results.push({ clientId: request.clientId, decision: 'needsSubscription', alreadyCounted: false });
    }
  }

  if (added > 0) {
    tx.update(r.account(ownerUid), { 'registrations.count': FieldValue.increment(added), updatedAt: ts(now) });
  }
  return { results, count };
}
