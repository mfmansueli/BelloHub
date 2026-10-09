// The sealed envelope, exactly as docs/06-PRIVACY-SECURITY.md section 3 specifies. This file is pure (no HPKE,
// no network) so the rules that bind a ciphertext to its kind, item and key are easy to read and to test.
//
//   suite  HPKE (RFC 9180) base mode, DHKEM(X25519, HKDF-SHA256) 0x0020, HKDF-SHA256 0x0001, ChaCha20-Poly1305 0x0003
//   info   UTF-8 "bellohub/inbox/v1"
//   aad    UTF-8 "bellohub/v1|<kind>|<itemId>|<keyId>"
//   keyId  base64url(SHA-256(pub)[0..<8])

import type { InboxKey } from '../api/types';
import { decodeBase64Url, encodeBase64Url } from '../lib/base64url';

export const SUITE_NAME = 'hpke-x25519-hkdf-sha256-chacha20poly1305' as const;
export const ENVELOPE_VERSION = 1 as const;
export const INFO_TEXT = 'bellohub/inbox/v1';

export type PayloadKind = 'intake' | 'checkin' | 'datarequest';

/** Largest plaintext per kind, after padding (docs/06 section 3.4). */
export const PAYLOAD_LIMITS: Readonly<Record<PayloadKind, number>> = {
  intake: 256 * 1024,
  checkin: 3 * 1024 * 1024,
  datarequest: 8 * 1024,
};

export class SealError extends Error {
  constructor(readonly reason: 'keyMismatch' | 'tooLarge' | 'unsupported') {
    super(reason);
    this.name = 'SealError';
  }
}

const encoder = new TextEncoder();

export function utf8(text: string): Uint8Array {
  return encoder.encode(text);
}

export function aadText(kind: PayloadKind, itemId: string, keyId: string): string {
  return `bellohub/v1|${kind}|${itemId}|${keyId}`;
}

/** `keyId = base64url(SHA-256(pub)[0..<8])`. */
export async function keyIdOf(publicKey: Uint8Array): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', new Uint8Array(publicKey)));
  return encodeBase64Url(digest.slice(0, 8));
}

/**
 * The page seals only to a key that is what it claims to be: an X25519 key of 32 bytes whose key id is the hash
 * of the key itself. A server that swaps the key and forgets to recompute the id is caught here (the stronger
 * check, against the key the professional's phone derived, is the app's, docs/06 section 3.2).
 */
export async function verifiedPublicKey(key: InboxKey): Promise<Uint8Array> {
  // The type says 'hpke-v1', the server's JSON may say anything.
  if ((key.alg as string) !== 'hpke-v1') throw new SealError('unsupported');
  let pub: Uint8Array;
  try {
    pub = decodeBase64Url(key.pub);
  } catch {
    throw new SealError('keyMismatch');
  }
  if (pub.length !== 32 || encodeBase64Url(pub) !== key.pub) throw new SealError('keyMismatch');
  if ((await keyIdOf(pub)) !== key.keyId) throw new SealError('keyMismatch');
  return pub;
}

/** The padding block: 1 KiB, or 16 KiB for a check-in that carries a photo, to blur sizes (docs/06 section 3.1). */
export function paddingUnit(kind: PayloadKind, hasPhoto: boolean): number {
  return kind === 'checkin' && hasPhoto ? 16 * 1024 : 1024;
}

/**
 * Serializes `payload` with a trailing `_pad` string so the UTF-8 length is a multiple of `unit`.
 * Padding characters are ASCII, so one character is one byte.
 */
export function padPayload(payload: object, unit: number): Uint8Array {
  const base = JSON.stringify({ ...payload, _pad: '' });
  const length = utf8(base).length;
  const fill = (unit - (length % unit)) % unit;
  return utf8(JSON.stringify({ ...payload, _pad: '0'.repeat(fill) }));
}

/** A fresh random UUID v4 for the item id (single-use, generated in the browser). */
export function newItemId(): string {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = ((bytes[6] ?? 0) & 0x0f) | 0x40;
  bytes[8] = ((bytes[8] ?? 0) & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

// MARK: - Payloads (docs/06 section 3.4)

export type AnswerValue = boolean | string | readonly string[];

/**
 * Schema 2 (D55): the answers only. Schema 1 also carried `clientName`, `guardianName`, a `consent` block and an
 * optional `signaturePng`; consents are the professional's own business now, so the page collects no signature and
 * the booking id is what ties the answers to the client.
 */
export interface IntakePayload {
  readonly schema: 2;
  readonly bookingId: string;
  readonly localeId: string;
  readonly formVersion: string;
  readonly answers: Readonly<Record<string, AnswerValue>>;
  readonly isForMinor: boolean;
  /** The name of the person under 18 the visit is for (a question of the form, not a signature). */
  readonly minorName?: string;
  readonly submittedAt: string;
}

export type Feeling = 'good' | 'okay' | 'irritated' | 'reaction';

export interface CheckinPayload {
  readonly schema: 1;
  readonly bookingId: string;
  readonly feeling: Feeling;
  readonly note?: string;
  /** JPEG as base64, at most 1.5 MB, EXIF stripped by the canvas re-encode. */
  readonly photoJpeg?: string;
  readonly submittedAt: string;
}

export interface DataRequestPayload {
  readonly schema: 1;
  readonly request: 'copy' | 'delete';
  readonly name: string;
  readonly phone: string;
  readonly note?: string;
  readonly submittedAt: string;
}

export type SealablePayload =
  | { readonly kind: 'intake'; readonly payload: IntakePayload }
  | { readonly kind: 'checkin'; readonly payload: CheckinPayload }
  | { readonly kind: 'datarequest'; readonly payload: DataRequestPayload };
