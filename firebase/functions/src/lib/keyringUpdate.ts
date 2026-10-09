import { FieldValue } from 'firebase-admin/firestore';

import type { InboxKeyringEntry } from './docs.js';
import { nextPruneAt } from './keyring.js';
import { ts } from './store.js';

/**
 * The account fields to write when the ring changes: the ring itself and the instant the cleanup job should drop
 * retired keys nobody can need any more (`pruneKeyrings`), cleared when every key is current.
 */
export function keyringUpdate(keyring: readonly InboxKeyringEntry[], now: number): Record<string, unknown> {
  const pruneAt = nextPruneAt(keyring);
  return {
    inboxKeyring: keyring,
    inboxKeyringPruneAt: pruneAt === undefined ? FieldValue.delete() : ts(pruneAt),
    updatedAt: ts(now)
  };
}
