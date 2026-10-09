// The published profile and the availability snapshot (API.md sections 4 and 6.2). What the professional's app
// publishes is exactly what a stranger's browser can read, so the schema is the privacy boundary: no field for a
// client, a habit, a note, a reason or a private price exists here.

import { z } from 'zod';

import {
  CancellationPolicySchema,
  CountryCode,
  CurrencyCode,
  E164,
  GuestsSchema,
  InboxKeySchema,
  Instant,
  LocalDateSchema,
  LocaleSchema,
  Minutes,
  MoneySchema,
  SlugSchema,
  TimeZoneId,
  Uuid,
  Weekday,
  looseText,
  text
} from './common.js';

const RulesText = z.partialRecord(LocaleSchema, looseText(2000, true));

export const ServicePublishSchema = z.strictObject({
  id: Uuid,
  name: text(80),
  category: text(60).optional(),
  durationMinutes: z.number().int().min(5).max(12 * 60),
  price: MoneySchema.optional()
});

export const AddOnPublishSchema = z.strictObject({
  id: Uuid,
  name: text(80),
  minutes: z.number().int().min(1).max(4 * 60),
  priceText: text(40).optional()
});

export const CredentialPublishSchema = z.strictObject({
  title: text(120),
  institution: text(120).optional(),
  year: z.number().int().min(1950).max(2100).optional(),
  registrationNumber: text(40).optional()
});

export const BookingSettingsPublishSchema = z.strictObject({
  acceptingBookings: z.boolean(),
  pausedUntil: Instant.optional(),
  requiresApproval: z.boolean(),
  maxGuests: GuestsSchema,
  maxDaysAhead: z.number().int().min(1).max(365)
});

// D55: the health form is only the questions. Consent texts are the professional's own business, handled outside the
// app; the server carries none, so a `consent` field here is refused like any other unknown field.
export const IntakePublishSchema = z.strictObject({
  formVersion: z.number().int().min(1).max(1000),
  template: z.record(z.string(), z.unknown())
});

const profileFields = {
  displayName: text(80),
  businessName: text(80).optional(),
  bio: text(600, true).optional(),
  city: text(80).optional(),
  regionCode: CountryCode,
  // 120 KB of image is about 165,000 characters of base64.
  photo: z
    .string()
    .max(165_000)
    .regex(/^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/)
    .optional(),
  timeZoneID: TimeZoneId,
  currencyCode: CurrencyCode,
  locales: z.array(LocaleSchema).min(1).max(6),
  whatsappE164: E164.optional(),
  credentials: z.array(CredentialPublishSchema).max(20),
  services: z.array(ServicePublishSchema).min(1).max(60),
  addOns: z.array(AddOnPublishSchema).max(30),
  booking: BookingSettingsPublishSchema,
  policy: CancellationPolicySchema,
  rulesText: RulesText,
  legalNotice: text(2000, true).optional(),
  inboxKey: InboxKeySchema
};

/** What `publishProfile` accepts. */
export const PublicProfileInputSchema = z.strictObject({
  ...profileFields,
  intake: IntakePublishSchema.optional()
});

/** What `getPublicPage` returns. */
export const PublicProfileSchema = z.strictObject({
  schemaVersion: z.literal(1),
  slug: SlugSchema,
  ...profileFields,
  updatedAt: Instant
});

export type PublicProfileInput = z.infer<typeof PublicProfileInputSchema>;
export type PublicProfileOutput = z.infer<typeof PublicProfileSchema>;

export const NoShowPolicySchema = z.strictObject({
  isOn: z.boolean(),
  limit: z.number().int().min(1).max(5),
  action: z.enum(['tell', 'approveNewBookings', 'pauseOnline']),
  lateCancelCounts: z.boolean(),
  countingMonths: z.union([z.literal(3), z.literal(6), z.literal(12)])
});

export const AvailabilityInputSchema = z.strictObject({
  timeZoneID: TimeZoneId,
  weekly: z
    .array(z.strictObject({ weekday: Weekday, startMinutes: Minutes, endMinutes: Minutes }))
    .max(56),
  breaks: z
    .array(z.strictObject({ weekday: Weekday.optional(), startMinutes: Minutes, endMinutes: Minutes }))
    .max(28),
  daysOff: z.array(z.strictObject({ startDate: LocalDateSchema, endDate: LocalDateSchema })).max(100),
  bufferMinutes: z.number().int().min(0).max(120),
  minNoticeHours: z.number().int().min(0).max(24 * 14),
  maxDaysAhead: z.number().int().min(1).max(365),
  busy: z
    .array(z.strictObject({ startsAt: Instant, endsAt: Instant, kind: z.enum(['appointment', 'block']) }))
    .max(600),
  noShow: NoShowPolicySchema,
  reminderHourLocal: z.number().int().min(0).max(23).optional()
});

export type AvailabilityInput = z.infer<typeof AvailabilityInputSchema>;
