// Shared building blocks of the request and response schemas (API.md section 4). Inputs are STRICT: an unknown field is
// rejected, so a client that starts sending something it should not (a health note, an extra identifier) fails loudly
// instead of being stored.

import { z } from 'zod';

import { cleanText } from '../lib/sanitize.js';
import { isLocalDate, isValidTimeZone } from '../lib/time.js';

export const LOCALES = ['pt-BR', 'pt-PT', 'es-MX', 'es-419', 'es', 'en', 'en-GB', 'it', 'fr', 'de', 'tr', 'id', 'hi', 'ar'] as const;
export type LocaleId = (typeof LOCALES)[number];
export const LocaleSchema = z.enum(LOCALES);

/** Routes of the web app and words that must never be a professional's address (docs/10 section 2). */
export const RESERVED_SLUGS: ReadonlySet<string> = new Set([
  'm', 'p', 'api', 'admin', 'app', 'www', 'help', 'support', 'static', 'assets', 'login', 'auth', 'bookings', 'book',
  'status', 'privacy', 'terms', 'legal', 'about'
]);

/** A required, cleaned, non-empty string of at most `max` characters. */
export const text = (max: number, multiline = false) =>
  z
    .string()
    .max(max * 4)
    .transform((value) => cleanText(value, multiline))
    .pipe(z.string().min(1).max(max));

/** Like `text` but an empty string is allowed. */
export const looseText = (max: number, multiline = false) =>
  z
    .string()
    .max(max * 4)
    .transform((value) => cleanText(value, multiline))
    .pipe(z.string().max(max));

export const Instant = z.iso.datetime({ offset: true });
export const LocalDateSchema = z.string().refine(isLocalDate, 'invalid local date');
export const E164 = z.string().regex(/^\+[1-9]\d{7,14}$/);
export const Email = z
  .email()
  .max(254)
  .transform((value) => value.trim().toLowerCase());
export const Token = z.string().regex(/^[A-Za-z0-9_-]{22}$/);
export const Uuid = z
  .string()
  .regex(/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/)
  .transform((value) => value.toLowerCase());
export const DocId = z.string().regex(/^[A-Za-z0-9_-]{1,64}$/);
export const SlugSchema = z
  .string()
  .regex(/^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$/)
  .refine((slug) => !slug.includes('--') && !RESERVED_SLUGS.has(slug), 'reserved slug');
export const TimeZoneId = z.string().max(64).refine(isValidTimeZone, 'unknown time zone');
export const CountryCode = z.string().regex(/^[A-Z]{2}$/);
export const CurrencyCode = z.string().regex(/^[A-Z]{3}$/);
export const HoldKey = z.string().regex(/^[A-Za-z0-9_-]{16,64}$/);
export const Weekday = z.number().int().min(1).max(7);
export const Minutes = z.number().int().min(0).max(24 * 60);

export const GuestsSchema = z.union([z.literal(0), z.literal(1), z.literal(2)]);

export const MoneySchema = z.strictObject({
  display: z.enum(['show', 'startingFrom', 'onRequest']),
  amount: z.number().min(0).max(1_000_000).multipleOf(0.01).optional()
});

export const CancellationPolicySchema = z.strictObject({
  freeWindowHours: z.union([z.literal(2), z.literal(12), z.literal(24), z.literal(48), z.literal(72)]),
  clientCanReschedule: z.boolean(),
  maxReschedules: z.number().int().min(0).max(20).optional(),
  afterWindowCancel: z.enum(['allow', 'message']),
  afterWindowReschedule: z.enum(['request', 'message']),
  askConfirmation: z.boolean(),
  graceMinutes: z.number().int().min(5).max(20)
});

export const InboxKeySchema = z.strictObject({
  keyId: z.string().regex(/^[A-Za-z0-9_-]{11}$/),
  alg: z.literal('hpke-v1'),
  pub: z.string().regex(/^[A-Za-z0-9_-]{43}$/)
});

export const EnvelopeSchema = z.strictObject({
  v: z.literal(1),
  suite: z.literal('hpke-x25519-hkdf-sha256-chacha20poly1305'),
  keyId: z.string().regex(/^[A-Za-z0-9_-]{11}$/),
  kind: z.enum(['intake', 'checkin', 'datarequest']),
  itemId: Uuid,
  enc: z.string().regex(/^[A-Za-z0-9_-]{43}$/),
  ct: z.string().regex(/^[A-Za-z0-9_-]{22,}$/).max(4 * 1024 * 1024 + 4096)
});

export type Envelope = z.infer<typeof EnvelopeSchema>;

export const VerificationSchema = z.discriminatedUnion('method', [
  z.strictObject({ method: z.literal('phone'), idToken: z.string().min(20).max(4096) }),
  z.strictObject({ method: z.literal('email'), proof: z.string().min(20).max(256) })
]);

export type Verification = z.infer<typeof VerificationSchema>;

/**
 * What `createBooking` accepts on top of the two proofs above: `whatsapp` (the client could not receive the code and
 * confirms with the professional on WhatsApp; the booking waits for her, unverified) and `device` (a trusted-device
 * token from an earlier confirmed booking with the same e-mail on the same page). Never accepted by `findBookings`.
 */
export const BookingVerificationSchema = z.discriminatedUnion('method', [
  ...VerificationSchema.options,
  z.strictObject({ method: z.literal('whatsapp') }),
  z.strictObject({ method: z.literal('device'), token: Token })
]);

export type BookingVerification = z.infer<typeof BookingVerificationSchema>;

/** The short reference of an unverified request: 5 characters from an alphabet without look-alikes (0/O, 1/I/L). */
export const ReferenceCode = z.string().regex(/^[2-9A-HJKMNP-Z]{5}$/);

export const PlanSchema = z.strictObject({
  state: z.enum(['none', 'active', 'grace', 'expired', 'revoked']),
  expiresAt: Instant.optional()
});

export const OkSchema = z.strictObject({ ok: z.literal(true) });

export const SlotResultAlternatives = z.strictObject({
  status: z.literal('slotTaken'),
  alternatives: z.array(Instant).max(5)
});

/** Parses an instant string into epoch milliseconds. Only call it on a string a schema already validated. */
export function instantMs(value: string): number {
  return Date.parse(value);
}

export function iso(ms: number): string {
  return new Date(ms).toISOString();
}
