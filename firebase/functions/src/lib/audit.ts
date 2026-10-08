import type { Transaction } from 'firebase-admin/firestore';

import type { Deps } from '../app/Deps.js';
import { keyedHash } from './crypto.js';
import type { AuditDoc } from './docs.js';
import { refs, ts } from './store.js';

const RETENTION_DAYS = 400;

/**
 * Security events without personal data (docs/11 section 2): a kind, a pseudonymous actor and a time. The actor is a
 * keyed hash of the uid, so the log does not name an account after the account is deleted. Never values (a key id is
 * public by design and is the only extra field).
 */
export function writeAudit(
  tx: Transaction,
  deps: Deps,
  event: { kind: AuditDoc['kind']; uid: string; keyId?: string }
): void {
  const now = deps.now();
  const doc: AuditDoc = {
    kind: event.kind,
    actor: keyedHash(deps.pepper, 'audit', event.uid).slice(0, 24),
    at: ts(now),
    expiresAt: ts(now + RETENTION_DAYS * 86_400_000),
    ...(event.keyId ? { keyId: event.keyId } : {})
  };
  tx.create(refs(deps.db).audits().doc(), doc);
}

/** The same outside a transaction. */
export async function recordAudit(deps: Deps, event: { kind: AuditDoc['kind']; uid: string; keyId?: string }): Promise<void> {
  await deps.db.runTransaction((tx) => {
    writeAudit(tx, deps, event);
    return Promise.resolve();
  });
}
