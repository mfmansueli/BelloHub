// Seal, then send (docs/06 section 3.5). The only network request that carries anything a client typed into a
// sealed page is `submitSealed`, and its body is an envelope: base64url bytes, a key id, a kind and an item id.
// The sealing library is a lazy chunk: it is fetched when the form is submitted, never at page load.
//
// A failed send keeps the sealed envelope in memory so a retry sends the same bytes (the item id is single-use on
// the server); it is never written to storage.

import { api } from '../api/client';
import type { InboxKey, SealedEnvelope } from '../api/types';
import type { PayloadKind } from './envelope';

export interface SealRequest {
  readonly kind: PayloadKind;
  readonly payload: object;
  readonly inboxKey: InboxKey;
  readonly hasPhoto?: boolean;
}

export async function sealInBrowser(request: SealRequest): Promise<SealedEnvelope> {
  const { sealPayload } = await import('./seal');
  return sealPayload(request);
}

export async function sendEnvelope(token: string, envelope: SealedEnvelope): Promise<void> {
  await api.submitSealed(token, envelope);
}
