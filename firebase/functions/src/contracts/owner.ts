// Owner functions (API.md section 6): the professional's iPhone app, authenticated and App Check protected.

import { z } from 'zod';

import {
  DocId,
  E164,
  Email,
  EnvelopeSchema,
  GuestsSchema,
  InboxKeySchema,
  Instant,
  LocalDateSchema,
  LocaleSchema,
  OkSchema,
  PlanSchema,
  SlugSchema,
  TimeZoneId,
  Token,
  Uuid,
  looseText,
  text,
  CountryCode
} from './common.js';
import { AvailabilityInputSchema, PublicProfileInputSchema } from './profile.js';

const Decision = z.enum(['allowed', 'needsSubscription']);

// MARK: - Account and registrations (D42)

export const ensureAccount = {
  input: z.strictObject({ countryCode: CountryCode, locale: LocaleSchema }),
  output: z.strictObject({
    uid: z.string(),
    appAccountToken: Uuid,
    dataRegion: z.literal('eu'),
    registrations: z.strictObject({ count: z.number().int(), freeLimit: z.number().int() }),
    plan: PlanSchema,
    slug: SlugSchema.optional()
  })
};

export const reserveRegistration = {
  input: z.strictObject({ clientId: Uuid, phone: E164.optional() }),
  output: z.strictObject({
    decision: Decision,
    count: z.number().int(),
    freeLimit: z.number().int(),
    alreadyCounted: z.boolean()
  })
};

export const reserveRegistrations = {
  input: z.strictObject({
    clients: z.array(z.strictObject({ clientId: Uuid, phone: E164.optional() })).min(1).max(200)
  }),
  output: z.strictObject({
    results: z.array(z.strictObject({ clientId: Uuid, decision: Decision, alreadyCounted: z.boolean() })),
    count: z.number().int(),
    freeLimit: z.number().int()
  })
};

export const syncPlan = {
  input: z.strictObject({ signedTransaction: z.string().min(20).max(20_000) }),
  output: z.strictObject({ plan: PlanSchema })
};

// MARK: - Slug, profile, availability

export const isSlugAvailable = {
  input: z.strictObject({ slug: z.string().max(64) }),
  output: z.strictObject({
    available: z.boolean(),
    reason: z.enum(['taken', 'reserved', 'invalid']).optional()
  })
};

export const claimSlug = {
  input: z.strictObject({ slug: SlugSchema }),
  output: z.strictObject({ slug: SlugSchema })
};

export const publishProfile = {
  input: z.strictObject({ profile: PublicProfileInputSchema }),
  output: z.strictObject({ slug: SlugSchema, updatedAt: Instant })
};

export const publishAvailability = {
  input: AvailabilityInputSchema,
  output: z.strictObject({ updatedAt: Instant })
};

export const updateInboxKey = {
  input: z.strictObject({
    inboxKey: InboxKeySchema,
    /** D51: the key being replaced was exposed; it stops accepting envelopes at once instead of after the 24 h grace. */
    compromised: z.boolean().optional()
  }),
  output: z.strictObject({
    keyring: z.array(
      z.strictObject({
        keyId: z.string(),
        createdAt: Instant,
        retiredAt: Instant.optional(),
        /** Retired keys only: the last instant a new envelope for this key is accepted. */
        acceptsUntil: Instant.optional(),
        compromisedAt: Instant.optional()
      })
    )
  })
};

// MARK: - Bookings, requests, waitlist

export const respondBookingRequest = {
  input: z.strictObject({ bookingId: DocId, decision: z.enum(['approve', 'decline']) }),
  output: z.strictObject({ status: z.enum(['confirmed', 'declined', 'needsSubscription']) })
};

export const respondRescheduleRequest = {
  input: z.strictObject({ requestId: DocId, decision: z.enum(['accept', 'decline']) }),
  output: z.strictObject({ status: z.enum(['accepted', 'declined', 'slotTaken']) })
};

export const cancelBookingByOwner = {
  input: z.strictObject({ bookingId: DocId, reason: looseText(200, true).optional() }),
  output: z.strictObject({ status: z.literal('cancelled') })
};

export const moveBookingByOwner = {
  input: z.strictObject({ bookingId: DocId, startsAt: Instant }),
  output: z.strictObject({ startsAt: Instant, endsAt: Instant })
};

/** "Message <client>" (3.6): the client's own link to change or cancel, for the message she sends herself. */
export const mintManageLink = {
  input: z.strictObject({ bookingId: DocId }),
  output: z.strictObject({ url: z.url().max(300), expiresAt: Instant })
};

/** Registers an appointment added by hand, creates a booking doc with phone/email hashes and mints a manage link. */
export const registerManualBooking = {
  input: z.strictObject({
    appointmentId: Uuid,
    serviceName: text(80),
    startsAt: Instant,
    endsAt: Instant,
    timeZoneID: TimeZoneId,
    client: z.strictObject({
      name: text(80),
      phone: E164,
      email: Email.optional(),
      locale: LocaleSchema.optional()
    })
  }),
  output: z.strictObject({
    bookingId: DocId,
    url: z.url().max(300),
    expiresAt: Instant
  })
};

export const suggestBookingTime = {
  input: z.strictObject({
    bookingId: DocId,
    startsAt: Instant,
    holdMinutes: z.number().int().min(15).max(1440).optional()
  }),
  output: z.discriminatedUnion('status', [
    z.strictObject({ status: z.literal('suggested'), holdKey: z.string(), holdId: z.string(), expiresAt: Instant }),
    z.strictObject({ status: z.literal('slotTaken') })
  ])
};

export const offerWaitlistSlot = {
  input: z.strictObject({
    waitlistId: DocId,
    serviceId: Uuid,
    addOnIds: z.array(Uuid).max(10).optional(),
    guests: GuestsSchema.optional(),
    startsAt: Instant,
    holdMinutes: z.number().int().min(15).max(1440).optional()
  }),
  output: z.discriminatedUnion('status', [
    z.strictObject({ status: z.literal('offered'), holdKey: z.string(), holdId: z.string(), expiresAt: Instant }),
    z.strictObject({ status: z.literal('slotTaken') })
  ])
};

export const removeWaitlistEntry = {
  input: z.strictObject({ waitlistId: DocId }),
  output: OkSchema
};

export const markNoShow = {
  input: z.strictObject({
    phone: E164,
    action: z.enum(['mark', 'forgive', 'reset']),
    markId: Uuid.optional(),
    markedAt: Instant.optional(),
    bookingId: DocId.optional()
  }),
  output: z.strictObject({ counted: z.number().int() })
};

export const setOnlineBookingStopped = {
  input: z.strictObject({ phone: E164, stopped: z.boolean() }),
  output: OkSchema
};

// MARK: - Portal

const PortalContent = z.strictObject({
  clientName: text(80),
  upcoming: z
    .array(
      z.strictObject({ serviceName: text(80), startsAt: Instant, endsAt: Instant, timeZoneID: TimeZoneId })
    )
    .max(20)
    .optional(),
  next: z.strictObject({ serviceName: text(80), recommendedDate: LocalDateSchema.optional() }).optional(),
  past: z
    .array(z.strictObject({ serviceName: text(80), date: LocalDateSchema, summary: text(300, true).optional() }))
    .max(100),
  aftercare: z
    .array(
      z.strictObject({
        title: text(120),
        lines: z.array(text(500, true)).max(20),
        date: LocalDateSchema.optional()
      })
    )
    .max(50),
  products: z.array(z.strictObject({ name: text(80), note: text(200).optional() })).max(30),
  rebook: z
    .strictObject({
      serviceId: Uuid,
      addOnIds: z.array(Uuid).max(10),
      client: z.strictObject({ name: text(80), phone: E164, email: Email.optional(), locale: LocaleSchema })
    })
    .optional()
});

export type PortalContentInput = z.infer<typeof PortalContent>;

export const publishPortal = {
  input: z.strictObject({
    token: Token,
    clientRef: Uuid,
    revoke: z.boolean().optional(),
    content: PortalContent.optional()
  }),
  output: z.strictObject({ ok: z.literal(true), expiresAt: Instant })
};

// MARK: - Mailbox, devices, deletion

export const getMailboxItem = {
  input: z.strictObject({ itemId: Uuid }),
  output: z.strictObject({
    itemId: Uuid,
    kind: z.enum(['intake', 'checkin', 'datarequest']),
    bookingId: z.string(),
    createdAt: Instant,
    envelope: EnvelopeSchema
  })
};

export const acknowledgeMailboxItem = {
  input: z.strictObject({ itemId: Uuid }),
  output: OkSchema
};

export const registerDevice = {
  input: z.strictObject({
    fcmToken: z.string().min(20).max(4096),
    platform: z.literal('ios'),
    locale: LocaleSchema.optional()
  }),
  output: OkSchema
};

export const unregisterDevice = {
  input: z.strictObject({ fcmToken: z.string().min(20).max(4096) }),
  output: OkSchema
};

export const deleteClientServerData = {
  input: z.strictObject({
    phone: E164.optional(),
    bookingIds: z.array(DocId).max(200).optional(),
    portalClientRef: Uuid.optional()
  }),
  output: z.strictObject({
    deleted: z.strictObject({
      bookings: z.number().int(),
      mailboxItems: z.number().int(),
      requests: z.number().int(),
      waitlist: z.number().int(),
      portals: z.number().int(),
      contacts: z.number().int()
    })
  })
};

export const deleteAccount = {
  input: z.strictObject({
    confirm: z.literal(true),
    /** A fresh Sign in with Apple authorization code (D44): the server revokes her Apple grant with it. */
    appleAuthorizationCode: z.string().min(10).max(2048).optional()
  }),
  output: z.strictObject({ ok: z.literal(true), appleRevocation: z.enum(['revoked', 'failed', 'skipped']) })
};
