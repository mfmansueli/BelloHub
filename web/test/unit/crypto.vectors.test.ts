// The browser's sealing against vectors made by a different implementation (docs/06 section 11 item 5).
//
// - RFC 9180 known answer for the product's suite, through the page's own library wiring.
// - inbox-v1.json (pyhpke + cryptography): sealing the same payload with the same item id and ephemeral input
//   gives the same envelope byte for byte, and opening the envelope gives the same plaintext.
// - Negative cases must not open.

import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { CipherSuite, HkdfSha256 } from '@hpke/core';
import { DhkemX25519HkdfSha256 } from '@hpke/dhkem-x25519';
import { Chacha20Poly1305 } from '@hpke/chacha20poly1305';

import type { InboxKey, SealedEnvelope } from '../../src/api/types';
import { decodeBase64Url } from '../../src/lib/base64url';
import { PAYLOAD_LIMITS, SealError } from '../../src/crypto/envelope';
import { framePlaintext, sealPayload } from '../../src/crypto/seal';
import { OpenRejected, openEnvelope } from '../support/open';

interface Recipient {
  privateKey: string;
  publicKey: string;
  keyId: string;
}

interface PositiveCase {
  name: string;
  recipient: string;
  kind: 'intake' | 'checkin' | 'datarequest';
  hasPhoto: boolean;
  itemId: string;
  ikmE: string;
  payload: object;
  plaintext: string;
  aad: string;
  envelope: SealedEnvelope;
}

interface NegativeCase {
  name: string;
  description: string;
  recipient: string;
  expect: 'open-fails' | 'reject-before-open';
  envelope: SealedEnvelope;
}

interface Vectors {
  recipients: Record<string, Recipient>;
  positive: PositiveCase[];
  negative: NegativeCase[];
}

interface RfcVector {
  vector: {
    info: string;
    ikmE: string;
    skRm: string;
    pkRm: string;
    enc: string;
    encryptions: { aad: string; pt: string; ct: string }[];
  };
}

const vectors = JSON.parse(readFileSync(new URL('../vectors/inbox-v1.json', import.meta.url), 'utf8')) as Vectors;
const rfc = JSON.parse(readFileSync(new URL('../vectors/rfc9180-vectors.json', import.meta.url), 'utf8')) as RfcVector;

function hex(text: string): Uint8Array {
  return Uint8Array.from(text.match(/../g) ?? [], (byte) => parseInt(byte, 16));
}

function buffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

function inboxKey(recipient: Recipient): InboxKey {
  return { keyId: recipient.keyId, alg: 'hpke-v1', pub: recipient.publicKey };
}

describe('RFC 9180 known answer (DHKEM X25519, HKDF-SHA256, ChaCha20-Poly1305, base mode)', () => {
  it('the page library reproduces the official encapsulation and ciphertexts', async () => {
    const suite = new CipherSuite({
      kem: new DhkemX25519HkdfSha256(),
      kdf: new HkdfSha256(),
      aead: new Chacha20Poly1305(),
    });
    const { info, ikmE, pkRm, enc, encryptions } = rfc.vector;
    const recipientPublicKey = await suite.kem.deserializePublicKey(buffer(hex(pkRm)));
    const sender = await suite.createSenderContext({
      recipientPublicKey,
      info: buffer(hex(info)),
      ekm: buffer(hex(ikmE)),
    });
    expect(Buffer.from(sender.enc).toString('hex')).toBe(enc);
    for (const item of encryptions) {
      const ct = await sender.seal(buffer(hex(item.pt)), buffer(hex(item.aad)));
      expect(Buffer.from(ct).toString('hex')).toBe(item.ct);
    }
  });

  it('opens the official ciphertexts with the official recipient key', async () => {
    const suite = new CipherSuite({
      kem: new DhkemX25519HkdfSha256(),
      kdf: new HkdfSha256(),
      aead: new Chacha20Poly1305(),
    });
    const { info, skRm, enc, encryptions } = rfc.vector;
    const recipientKey = await suite.kem.importKey('raw', buffer(hex(skRm)), false);
    const context = await suite.createRecipientContext({ recipientKey, info: buffer(hex(info)), enc: buffer(hex(enc)) });
    for (const item of encryptions) {
      const pt = await context.open(buffer(hex(item.ct)), buffer(hex(item.aad)));
      expect(Buffer.from(pt).toString('hex')).toBe(item.pt);
    }
  });
});

describe('inbox-v1 vectors made by pyhpke', () => {
  it('has the cases the iOS side will reuse', () => {
    expect(vectors.positive.length).toBeGreaterThanOrEqual(9);
    expect(vectors.negative.length).toBeGreaterThanOrEqual(10);
  });

  for (const item of vectors.positive) {
    it(`seals "${item.name}" to exactly the independent envelope`, async () => {
      const recipient = vectors.recipients[item.recipient];
      expect(recipient).toBeDefined();
      if (recipient === undefined) return;
      const request = { kind: item.kind, payload: item.payload, inboxKey: inboxKey(recipient), hasPhoto: item.hasPhoto, itemId: item.itemId };
      // The plaintext framing (padding block, field order, JSON) is the same bytes the other side wrote.
      expect(new TextDecoder().decode(framePlaintext(request))).toBe(item.plaintext);
      const envelope = await sealPayload(request, { ephemeralIkm: decodeBase64Url(item.ikmE) });
      expect(envelope).toEqual(item.envelope);
    });

    it(`opens "${item.name}" to the independent plaintext`, async () => {
      const recipient = vectors.recipients[item.recipient];
      if (recipient === undefined) throw new Error('missing recipient');
      const plaintext = await openEnvelope(item.envelope, decodeBase64Url(recipient.privateKey));
      expect(plaintext).toBe(item.plaintext);
      expect(new TextEncoder().encode(plaintext).length % (item.kind === 'checkin' && item.hasPhoto ? 16384 : 1024)).toBe(0);
    });
  }

  for (const item of vectors.negative) {
    it(`rejects "${item.name}": ${item.description}`, async () => {
      const recipient = vectors.recipients[item.recipient];
      if (recipient === undefined) throw new Error('missing recipient');
      const attempt = openEnvelope(item.envelope, decodeBase64Url(recipient.privateKey));
      if (item.expect === 'reject-before-open') {
        await expect(attempt).rejects.toBeInstanceOf(OpenRejected);
      } else {
        await expect(attempt).rejects.toBeDefined();
      }
    });
  }

  it('refuses to seal to a key whose id is not the hash of the key', async () => {
    const recipient = vectors.recipients['r1'];
    if (recipient === undefined) throw new Error('missing recipient');
    const forged = { ...inboxKey(recipient), keyId: 'AAAAAAAAAAA' };
    await expect(sealPayload({ kind: 'datarequest', payload: { schema: 1 }, inboxKey: forged })).rejects.toBeInstanceOf(SealError);
  });

  it('refuses a payload above the limit of its kind', async () => {
    const recipient = vectors.recipients['r1'];
    if (recipient === undefined) throw new Error('missing recipient');
    const big = { schema: 1, request: 'copy', name: 'x', phone: '+1', note: 'a'.repeat(PAYLOAD_LIMITS.datarequest), submittedAt: 'now' };
    await expect(sealPayload({ kind: 'datarequest', payload: big, inboxKey: inboxKey(recipient) })).rejects.toMatchObject({ reason: 'tooLarge' });
  });
});
