// Opens an envelope the way the iPhone will (test-only: the page never opens anything). Used by the vector tests
// and by the mock server to prove that what the browser sealed is what the user typed.

import { CipherSuite, HkdfSha256 } from '@hpke/core';
import { DhkemX25519HkdfSha256 } from '@hpke/dhkem-x25519';
import { Chacha20Poly1305 } from '@hpke/chacha20poly1305';
import { createPrivateKey, createPublicKey } from 'node:crypto';

import type { SealedEnvelope } from '../../src/api/types';
import { decodeBase64Url, encodeBase64Url } from '../../src/lib/base64url';
import { INFO_TEXT, SUITE_NAME, aadText, keyIdOf, utf8 } from '../../src/crypto/envelope';

function buffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

export class OpenRejected extends Error {}

/** Opens `envelope` with the raw 32-byte X25519 private key; throws when it must be rejected. */
export async function openEnvelope(envelope: SealedEnvelope, privateKey: Uint8Array): Promise<string> {
  if ((envelope.v as number) !== 1) throw new OpenRejected('unsupported version');
  if ((envelope.suite as string) !== SUITE_NAME) throw new OpenRejected('unsupported suite');
  const suite = new CipherSuite({
    kem: new DhkemX25519HkdfSha256(),
    kdf: new HkdfSha256(),
    aead: new Chacha20Poly1305(),
  });
  const recipientKey = await suite.kem.importKey('raw', buffer(privateKey), false);
  const context = await suite.createRecipientContext({
    recipientKey,
    info: buffer(utf8(INFO_TEXT)),
    enc: buffer(decodeBase64Url(envelope.enc)),
  });
  const plaintext = await context.open(
    buffer(decodeBase64Url(envelope.ct)),
    buffer(utf8(aadText(envelope.kind, envelope.itemId, envelope.keyId))),
  );
  return new TextDecoder().decode(plaintext);
}

/** The X25519 public key of a raw private key (Node's OpenSSL, independent of hpke-js). */
export function x25519PublicFromSeed(seed: Uint8Array): Uint8Array {
  const pkcs8Prefix = Buffer.from('302e020100300506032b656e04220420', 'hex');
  const privateKey = createPrivateKey({ key: Buffer.concat([pkcs8Prefix, seed]), format: 'der', type: 'pkcs8' });
  const jwk = createPublicKey(privateKey).export({ format: 'jwk' });
  return decodeBase64Url(jwk.x ?? '');
}

/** A complete inbox key pair from a seed: the private bytes and the published key. */
export async function inboxKeyFromSeed(seed: Uint8Array): Promise<{
  readonly seed: Uint8Array;
  readonly publicKey: { keyId: string; alg: 'hpke-v1'; pub: string };
}> {
  const pub = x25519PublicFromSeed(seed);
  return { seed, publicKey: { keyId: await keyIdOf(pub), alg: 'hpke-v1', pub: encodeBase64Url(pub) } };
}
