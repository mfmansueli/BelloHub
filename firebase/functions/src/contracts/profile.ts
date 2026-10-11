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

/** D56: prep and clean-up time of a service or a busy visit, 0 to 60 minutes. */
const ExtraMinutes = z.number().int().min(0).max(60);

/** D56: the processing stretch starts after the visit starts and ends by its visible end. */
function processingInsideVisit(value: { durationMinutes?: number; processingStartMinutes?: number | undefined; processingMinutes?: number | undefined }): boolean {
  const length = value.processingMinutes ?? 0;
  if (length === 0) return true;
  const start = value.processingStartMinutes ?? 0;
  return value.durationMinutes === undefined || start + length <= value.durationMinutes;
}

const RulesText = z.partialRecord(LocaleSchema, looseText(2000, true));

// Where she works (owner, 2026-10-11). The app formats the address and builds both map links from the text (no SDK, no
// geocoding); the server only checks their shape so a link can never point anywhere else, and prints them as they are.
const MapsSchema = z.strictObject({
  apple: z.string().max(2000).regex(/^https:\/\/maps\.apple\.com\/\?address=[A-Za-z0-9%._~-]+$/),
  google: z.string().max(2000).regex(/^https:\/\/www\.google\.com\/maps\/search\/\?api=1&query=[A-Za-z0-9%._~-]+$/)
});

const locationFields = {
  lines: z.array(text(120)).min(1).max(3),
  directions: text(300).optional(),
  maps: MapsSchema
};

/** The address as clients see it (`getPublicPage` with `public`, `getBooking` for a confirmed booking). */
export const PublicLocationSchema = z.strictObject(locationFields);

/** What the app publishes: the address and who may see it (`confirmed` is the default; `public` adds the page). */
export const LocationPublishSchema = z.strictObject({
  ...locationFields,
  visibility: z.enum(['confirmed', 'public'])
});

export const ServicePublishSchema = z.strictObject({
  id: Uuid,
  name: text(80),
  category: text(60).optional(),
  durationMinutes: z.number().int().min(5).max(12 * 60),
  price: MoneySchema.optional(),
  // D56: the visit's shape. Extra time is blocked around it and never shown; processing leaves her free inside it.
  prepMinutes: ExtraMinutes.optional(),
  cleanupMinutes: ExtraMinutes.optional(),
  processingStartMinutes: z.number().int().min(0).max(12 * 60).optional(),
  processingMinutes: z.number().int().min(0).max(12 * 60).optional()
}).refine(processingInsideVisit, { message: 'processing must lie inside the visit', path: ['processingMinutes'] });

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
  intake: IntakePublishSchema.optional(),
  location: LocationPublishSchema.optional()
});

/** What `getPublicPage` returns. */
export const PublicProfileSchema = z.strictObject({
  schemaVersion: z.literal(1),
  slug: SlugSchema,
  ...profileFields,
  /** Only when she chose to show her address on the booking page. */
  location: PublicLocationSchema.optional(),
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
  // D56: 0 is "match the service"; absent means 15. compactDay absent means on.
  slotStepMinutes: z.union([z.literal(0), z.literal(10), z.literal(15), z.literal(20), z.literal(30), z.literal(60)]).optional(),
  compactDay: z.boolean().optional(),
  busy: z
    .array(
      z.strictObject({
        startsAt: Instant,
        endsAt: Instant,
        kind: z.enum(['appointment', 'block']),
        prepMinutes: ExtraMinutes.optional(),
        cleanupMinutes: ExtraMinutes.optional(),
        processingStartMinutes: z.number().int().min(0).max(24 * 60).optional(),
        processingMinutes: z.number().int().min(0).max(24 * 60).optional()
      })
    )
    .max(600),
  noShow: NoShowPolicySchema,
  reminderHourLocal: z.number().int().min(0).max(23).optional()
});

export type AvailabilityInput = z.infer<typeof AvailabilityInputSchema>;
