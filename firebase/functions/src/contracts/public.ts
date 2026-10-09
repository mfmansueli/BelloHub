// Public and token functions (API.md section 5): the web booking app.

import { z } from 'zod';

import {
  CancellationPolicySchema,
  E164,
  Email,
  EnvelopeSchema,
  GuestsSchema,
  HoldKey,
  InboxKeySchema,
  Instant,
  LocalDateSchema,
  LocaleSchema,
  OkSchema,
  SlotResultAlternatives,
  SlugSchema,
  TimeZoneId,
  Token,
  Uuid,
  VerificationSchema,
  looseText,
  text
} from './common.js';
import { PublicProfileSchema } from './profile.js';

const RulesText = z.partialRecord(LocaleSchema, z.string());
const BookingStatus = z.enum(['confirmed', 'pendingApproval', 'cancelledByClient', 'cancelledByPro', 'declined', 'noShow']);

// MARK: - Page and slots

export const getPublicPage = {
  input: z.strictObject({ slug: SlugSchema }),
  output: z.strictObject({
    profile: PublicProfileSchema,
    intakeAvailable: z.boolean(),
    features: z.strictObject({ whatsAppAutomation: z.boolean(), smsCallingCodes: z.array(z.string()) }),
    serverTime: Instant
  })
};

export const getSlots = {
  input: z.strictObject({
    slug: SlugSchema,
    serviceId: Uuid,
    addOnIds: z.array(Uuid).max(10).optional(),
    guests: GuestsSchema.optional(),
    from: LocalDateSchema,
    to: LocalDateSchema,
    holdKey: HoldKey.optional(),
    rescheduleToken: Token.optional()
  }),
  output: z.strictObject({
    timeZoneID: TimeZoneId,
    durationMinutes: z.number().int(),
    paused: z.boolean(),
    days: z.array(z.strictObject({ date: LocalDateSchema, slots: z.array(Instant) }))
  })
};

const offerFields = {
  slug: SlugSchema,
  serviceId: Uuid,
  addOnIds: z.array(Uuid).max(10).optional(),
  guests: GuestsSchema.optional()
};

export const holdSlot = {
  input: z.strictObject({ ...offerFields, startsAt: Instant, holdKey: HoldKey }),
  output: z.discriminatedUnion('status', [
    z.strictObject({ status: z.literal('held'), holdId: z.string(), expiresAt: Instant }),
    SlotResultAlternatives,
    z.strictObject({ status: z.literal('paused') })
  ])
};

export const getHold = {
  input: z.strictObject({ slug: SlugSchema, holdKey: HoldKey }),
  output: z.strictObject({
    serviceId: Uuid,
    addOnIds: z.array(Uuid),
    guests: z.number().int(),
    startsAt: Instant,
    endsAt: Instant,
    expiresAt: Instant
  })
};

// MARK: - Verification

export const sendEmailCode = {
  input: z.strictObject({ slug: SlugSchema, email: Email, locale: LocaleSchema, purpose: z.enum(['booking', 'find']) }),
  output: z.strictObject({ resendAfterSeconds: z.literal(30), expiresInSeconds: z.literal(600) })
};

export const verifyEmailCode = {
  input: z.strictObject({ email: Email, code: z.string().regex(/^\d{6}$/) }),
  output: z.strictObject({ proof: z.string(), expiresInSeconds: z.literal(1800) })
};

// MARK: - Booking

const ClientSchema = z.strictObject({ name: text(80), phone: E164, email: Email.optional(), locale: LocaleSchema });

export const createBooking = {
  input: z.strictObject({
    ...offerFields,
    startsAt: Instant,
    client: ClientSchema,
    note: looseText(300, true).optional(),
    verification: VerificationSchema,
    idempotencyKey: Uuid,
    holdKey: HoldKey.optional()
  }),
  output: z.discriminatedUnion('status', [
    z.strictObject({
      status: z.enum(['confirmed', 'pendingApproval']),
      bookingId: z.string(),
      manageToken: Token,
      startsAt: Instant,
      endsAt: Instant,
      timeZoneID: TimeZoneId,
      serviceName: z.string(),
      emailSent: z.boolean()
    }),
    SlotResultAlternatives,
    z.strictObject({ status: z.literal('paused'), pausedUntil: Instant.optional() })
  ])
};

export const findBookings = {
  input: z.strictObject({
    slug: SlugSchema,
    phone: E164.optional(),
    email: Email.optional(),
    verification: VerificationSchema
  }),
  output: z.strictObject({
    bookings: z.array(
      z.strictObject({
        bookingId: z.string(),
        manageToken: Token,
        serviceName: z.string(),
        startsAt: Instant,
        endsAt: Instant,
        timeZoneID: TimeZoneId,
        status: z.enum(['confirmed', 'pendingApproval'])
      })
    )
  })
};

export const joinWaitlist = {
  input: z.strictObject({
    slug: SlugSchema,
    serviceId: Uuid.optional(),
    name: text(80),
    phone: E164,
    locale: LocaleSchema,
    dayFrom: LocalDateSchema,
    dayTo: LocalDateSchema
  }),
  output: OkSchema
};

// MARK: - By manage token

export const getBooking = {
  input: z.strictObject({ token: Token }),
  output: z.strictObject({
    bookingId: z.string(),
    status: BookingStatus,
    phase: z.enum(['upcoming', 'inProgress', 'past']),
    slug: SlugSchema,
    professional: z.strictObject({
      displayName: z.string(),
      businessName: z.string().optional(),
      whatsappE164: E164.optional()
    }),
    service: z.strictObject({ id: Uuid, name: z.string() }),
    addOns: z.array(z.strictObject({ id: Uuid, name: z.string(), minutes: z.number().int() })),
    guestCount: z.number().int(),
    startsAt: Instant,
    endsAt: Instant,
    durationMinutes: z.number().int(),
    timeZoneID: TimeZoneId,
    serverTime: Instant,
    client: z.strictObject({ name: z.string() }),
    /** D47: the policy in force when the booking was made. */
    policy: CancellationPolicySchema,
    rulesText: RulesText,
    /** D47: under the no-show policy of booking time, a late cancellation counts as a missed visit. */
    lateCancelCounts: z.boolean(),
    actions: z.strictObject({
      cancel: z.enum(['free', 'allowedWithWarning', 'askByMessage', 'unavailable']),
      reschedule: z.enum(['direct', 'request', 'message', 'unavailable']),
      isInsideFreeWindow: z.boolean(),
      hoursUntilStart: z.number(),
      cancellationWouldBeLate: z.boolean(),
      canConfirmPresence: z.boolean(),
      canReportLate: z.boolean()
    }),
    clientConfirmedAt: Instant.optional(),
    lateByMinutes: z.number().int().optional(),
    rescheduleCount: z.number().int(),
    pendingReschedule: z
      .strictObject({ requestedStart: Instant, status: z.enum(['pending', 'declined']) })
      .optional(),
    intakeRequired: z.boolean(),
    tokenExpiresAt: Instant
  })
};

export const confirmPresence = {
  input: z.strictObject({ token: Token }),
  output: z.strictObject({ clientConfirmedAt: Instant })
};

export const reportLate = {
  input: z.strictObject({
    token: Token,
    minutes: z.union([z.literal(10), z.literal(15), z.literal(20), z.literal(30)])
  }),
  output: z.strictObject({ lateByMinutes: z.number().int(), reportedAt: Instant })
};

export const cancelBooking = {
  input: z.strictObject({
    token: Token,
    reason: looseText(200, true).optional(),
    acceptLateWarning: z.boolean().optional()
  }),
  output: z.strictObject({ status: z.literal('cancelled'), isLateCancellation: z.boolean() })
};

export const rescheduleBooking = {
  input: z.strictObject({ token: Token, startsAt: Instant }),
  output: z.discriminatedUnion('status', [
    z.strictObject({
      status: z.literal('moved'),
      startsAt: Instant,
      endsAt: Instant,
      rescheduleCount: z.number().int()
    }),
    SlotResultAlternatives
  ])
};

export const requestReschedule = {
  input: z.strictObject({ token: Token, startsAt: Instant, note: looseText(300, true).optional() }),
  output: z.discriminatedUnion('status', [z.strictObject({ status: z.literal('requested') }), SlotResultAlternatives])
};

export const rebook = {
  input: z.strictObject({
    token: Token,
    serviceId: Uuid.optional(),
    addOnIds: z.array(Uuid).max(10).optional(),
    startsAt: Instant,
    idempotencyKey: Uuid
  }),
  output: createBooking.output
};

// MARK: - Sealed mailbox (client side)

export const getFormContext = {
  input: z.strictObject({ token: Token }),
  output: z.strictObject({
    bookingId: z.string(),
    professional: z.strictObject({ displayName: z.string() }),
    formVersion: z.number().int(),
    template: z.record(z.string(), z.unknown()),
    consent: z.partialRecord(
      LocaleSchema,
      z.strictObject({ textVersion: z.string(), text: z.string(), guardianText: z.string().optional() })
    ),
    inboxKey: InboxKeySchema,
    intakeCompletedWithinMonths: z.boolean()
  })
};

export const submitSealed = {
  input: z.strictObject({ token: Token, envelope: EnvelopeSchema }),
  output: OkSchema
};

// MARK: - Portal

export const getPortal = {
  input: z.strictObject({ token: Token }),
  output: z.strictObject({
    slug: SlugSchema,
    professional: z.strictObject({
      displayName: z.string(),
      businessName: z.string().optional(),
      whatsappE164: E164.optional()
    }),
    clientName: z.string(),
    upcoming: z.array(
      z.strictObject({ serviceName: z.string(), startsAt: Instant, endsAt: Instant, timeZoneID: TimeZoneId })
    ),
    next: z.strictObject({ serviceName: z.string(), recommendedDate: LocalDateSchema.optional() }).optional(),
    past: z.array(z.strictObject({ serviceName: z.string(), date: LocalDateSchema, summary: z.string().optional() })),
    aftercare: z.array(z.strictObject({ title: z.string(), lines: z.array(z.string()), date: LocalDateSchema.optional() })),
    products: z.array(z.strictObject({ name: z.string(), note: z.string().optional() })),
    rebook: z.strictObject({ serviceId: Uuid, addOnIds: z.array(Uuid) }).optional(),
    expiresAt: Instant
  })
};
