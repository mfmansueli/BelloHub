// Hashing and token helpers. Tokens are 128-bit random values; the server keeps only their SHA-256
// (docs/06 section 5). Phones, emails and IP addresses are never stored or indexed in the clear when a keyed hash is
// enough: the HMAC pepper lives in Secret Manager (`PHONE_HASH_PEPPER`, H4).

import { createHash, createHmac, timingSafeEqual } from 'node:crypto';

export function sha256Hex(value: string): string {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

/** A keyed hash, domain-separated by `label` so a phone hash can never equal an email hash. */
export function keyedHash(pepper: string, label: string, value: string): string {
  return createHmac('sha256', pepper).update(`${label}\u0000${value}`, 'utf8').digest('hex');
}

/** A keyed digest as bytes (the keyed hash above is its hex form), domain-separated by `label`. */
export function keyedDigest(pepper: string, label: string, value: string): Buffer {
  return createHmac('sha256', pepper).update(`${label}\u0000${value}`, 'utf8').digest();
}

export function base64url(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString('base64url');
}

export function fromBase64url(text: string): Buffer | null {
  if (!/^[A-Za-z0-9_-]*$/.test(text)) return null;
  return Buffer.from(text, 'base64url');
}

/** Exact byte length of a base64url string once decoded (no padding), without decoding it. */
export function base64urlByteLength(text: string): number {
  return Math.floor((text.length * 3) / 4);
}

export function safeEqualHex(a: string, b: string): boolean {
  const left = Buffer.from(a, 'utf8');
  const right = Buffer.from(b, 'utf8');
  return left.length === right.length && timingSafeEqual(left, right);
}

/** The first 8 bytes of SHA-256(pub), base64url: the key id of the sealed mailbox (docs/06 section 3.2). */
export function inboxKeyId(pubBase64url: string): string | null {
  const pub = fromBase64url(pubBase64url);
  if (pub?.length !== 32) return null;
  return base64url(createHash('sha256').update(pub).digest().subarray(0, 8));
}
