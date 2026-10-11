// Seals a payload to the professional's inbox key in the browser (docs/06 section 3). This module pulls in
// hpke-js, so it is only ever loaded with a dynamic `import()` by the form, check-in and my-data pages.
//
// Library choice (documented in docs/agent-notes/web.md): `@hpke/core` + `@hpke/dhkem-x25519` +
// `@hpke/chacha20poly1305`, pinned exactly and bundled into our own JS (no runtime third-party origin), as
// docs/06 section 3.1 names. WebCrypto alone cannot do it: it has no ChaCha20-Poly1305, and X25519 is missing
// from older Android and iOS browsers, while `@hpke/dhkem-x25519` is a pure-JS DHKEM that works everywhere.
// No custom cryptography is written here: this file only wires the suite and the framing around it.

import { CipherSuite, HkdfSha256 } from '@hpke/core';
import { DhkemX25519HkdfSha256 } from '@hpke/dhkem-x25519';
import { Chacha20Poly1305 } from '@hpke/chacha20poly1305';

import type { InboxKey, SealedEnvelope } from '../api/types';
import { encodeBase64Url } from '../lib/base64url';
import {
  ENVELOPE_VERSION,
  INFO_TEXT,
  PAYLOAD_LIMITS,
  SUITE_NAME,
  SealError,
  aadText,
  newItemId,
  padPayload,
  paddingUnit,
  utf8,
  verifiedPublicKey,
  type PayloadKind,
} from './envelope';

export interface SealRequest {
  readonly kind: PayloadKind;
  /** The payload object, without `_pad` (the padding is added here). */
  readonly payload: object;
  readonly inboxKey: InboxKey;
  /** True when a check-in carries a photo, which selects the 16 KiB padding block. */
  readonly hasPhoto?: boolean;
  /** Fixed item id, for tests only. A new random UUID v4 is used otherwise. */
  readonly itemId?: string;
}

/** Test-only hooks. Production code never passes them. */
export interface SealTestHooks {
  /** Input key material the ephemeral key pair is derived from (RFC 9180 `ikmE`), for reproducible vectors. */
  readonly ephemeralIkm?: Uint8Array;
}

function buffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

function createSuite(): CipherSuite {
  return new CipherSuite({
    kem: new DhkemX25519HkdfSha256(),
    kdf: new HkdfSha256(),
    aead: new Chacha20Poly1305(),
  });
}

/** The exact bytes that get encrypted, exposed so the tests can assert the plaintext framing. */
export function framePlaintext(request: SealRequest): Uint8Array {
  return padPayload(request.payload, paddingUnit(request.kind, request.hasPhoto === true));
}

export async function sealPayload(request: SealRequest, hooks: SealTestHooks = {}): Promise<SealedEnvelope> {
  const publicKey = await verifiedPublicKey(request.inboxKey);
  const plaintext = framePlaintext(request);
  if (plaintext.length > PAYLOAD_LIMITS[request.kind]) throw new SealError('tooLarge');

  const itemId = request.itemId ?? newItemId();
  const suite = createSuite();
  const recipientPublicKey = await suite.kem.deserializePublicKey(buffer(publicKey));
  const sender = await suite.createSenderContext({
    recipientPublicKey,
    info: buffer(utf8(INFO_TEXT)),
    ...(hooks.ephemeralIkm === undefined ? {} : { ekm: buffer(hooks.ephemeralIkm) }),
  });
  const ciphertext = await sender.seal(buffer(plaintext), buffer(utf8(aadText(request.kind, itemId, request.inboxKey.keyId))));

  return {
    v: ENVELOPE_VERSION,
    suite: SUITE_NAME,
    keyId: request.inboxKey.keyId,
    kind: request.kind,
    itemId,
    enc: encodeBase64Url(new Uint8Array(sender.enc)),
    ct: encodeBase64Url(new Uint8Array(ciphertext)),
  };
}
