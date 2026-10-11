// Unverified requests (verify-fallback item 1): "I didn't get the code" -> "Confirm with <her> on WhatsApp". The page
// creates the booking as a request without any proof; the professional matches the client's WhatsApp message by its
// reference code and approves as usual. Pure helpers here; the booking itself is written by bookingCreate.ts and the
// release of an unanswered request by jobs/steps/expireRequests.ts.

import { UNVERIFIED_REQUEST_HOURS } from '../config/limits.js';
import type { Random } from './random.js';

/** No 0/O, no 1/I/L: a code read aloud or typed from a chat must not be ambiguous. 31 characters. */
export const REFERENCE_ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
export const REFERENCE_LENGTH = 5;

/** A short reference the client quotes in her message. Not a secret and not unique by force: it only helps her match. */
export function newReference(random: Random): string {
  return [...random.bytes(REFERENCE_LENGTH)].map((byte) => REFERENCE_ALPHABET[byte % REFERENCE_ALPHABET.length]).join('');
}

/** The request is released 24 hours after it was made, or when the visit would start, whichever comes first. */
export function requestExpiry(now: number, startsAt: number): number {
  return Math.min(now + UNVERIFIED_REQUEST_HOURS * 3_600_000, startsAt);
}
