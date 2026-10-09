import type { Deps } from '../app/Deps.js';
import { notifyOwner } from '../push/notifyOwner.js';

/** A sealed item arrived: a SILENT push (content-available, no text) wakes the app to sync the mailbox (docs/06 section 3.5). */
export async function handleInboxItemCreated(deps: Deps, ownerUid: string, itemId: string): Promise<void> {
  await notifyOwner(deps, ownerUid, { kind: 'mailbox', id: itemId });
}
