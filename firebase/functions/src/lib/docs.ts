// The shape of every stored document and the collection names (docs/05 layer B, docs/11 section 2).
// Dates are Firestore Timestamps (UTC). All of this is operational data: nothing here can hold a health answer.

import type { Timestamp } from 'firebase-admin/firestore';

import type { LocaleId } from '../contracts/common.js';
import type { CancellationPolicy, NoShowAction, NoShowMark, NoShowPolicy, PendingReason, PlanState } from './rules.js';

export const C = {
  accounts: 'accounts',
  registrations: 'registrations',
  slugs: 'slugs',
  publicProfiles: 'publicProfiles',
  intakeForms: 'intakeForms',
  availability: 'availability',
  bookings: 'bookings',
  holds: 'holds',
  inbox: 'inbox',
  items: 'items',
  portal: 'portal',
  rescheduleRequests: 'rescheduleRequests',
  waitlist: 'waitlist',
  contacts: 'contacts',
  devices: 'devices',
  tokens: 'tokens',
  calendarLocks: 'calendarLocks',
  emailCodes: 'emailCodes',
  emailProofs: 'emailProofs',
  idempotency: 'idempotency',
  rate: 'rate',
  audit: 'audit',
  /** Emulator only: what the fake push sender and fake mailer saw, so end-to-end tests can wait on it. */
  emulatorOutbox: 'emulatorOutbox'
} as const;

export interface InboxKeyringEntry {
  keyId: string;
  pub: string;
  createdAt: Timestamp;
  retiredAt?: Timestamp;
  /** D51: the rotation that retired this key reported it as exposed; it stopped accepting envelopes at `retiredAt`. */
  compromisedAt?: Timestamp;
}

export interface AccountDoc {
  schemaVersion: 1;
  phone?: string;
  slug?: string;
  countryCode: string;
  locale: LocaleId;
  dataRegion: 'eu';
  /** Written by functions only (App Store verification). The client reads it. */
  plan: { state: PlanState; expiresAt?: Timestamp; source?: 'appStore' };
  /** Written by functions only. Never decremented. */
  registrations: { count: number; freeLimit: number };
  inboxKeyring: InboxKeyringEntry[];
  /** When the cleanup job should drop retired keys that no envelope can reference any more (absent: nothing to drop). */
  inboxKeyringPruneAt?: Timestamp;
  deletion: { requestedAt?: Timestamp };
  appAccountToken: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/** One per client id (or per booking-registered phone), never deleted by a client delete. `alias` entries only make a
 * client id idempotent after her phone was already counted; they do not count themselves. */
export interface RegistrationDoc {
  registeredAt: Timestamp;
  source: 'app' | 'booking' | 'alias';
}

export interface SlugDoc {
  ownerUid: string;
  claimedAt: Timestamp;
}

/**
 * D56: the shape of a visit, all optional (absent is 0). On a service it is what she set; on a booking, a hold or a
 * busy appointment it is a snapshot taken when it was made, so a later edit of the service never moves a booked visit.
 */
export interface TimingFields {
  prepMinutes?: number;
  cleanupMinutes?: number;
  processingStartMinutes?: number;
  processingMinutes?: number;
}

export interface ProfileService extends TimingFields {
  id: string;
  name: string;
  category?: string;
  durationMinutes: number;
  price?: { display: 'show' | 'startingFrom' | 'onRequest'; amount?: number };
}

export interface ProfileAddOn {
  id: string;
  name: string;
  minutes: number;
  priceText?: string;
}

export interface PublicProfileDoc {
  schemaVersion: 1;
  slug: string;
  displayName: string;
  businessName?: string;
  bio?: string;
  city?: string;
  regionCode: string;
  photo?: string;
  timeZoneID: string;
  currencyCode: string;
  locales: LocaleId[];
  whatsappE164?: string;
  credentials: { title: string; institution?: string; year?: number; registrationNumber?: string }[];
  services: ProfileService[];
  addOns: ProfileAddOn[];
  booking: {
    acceptingBookings: boolean;
    pausedUntil?: Timestamp;
    requiresApproval: boolean;
    maxGuests: 0 | 1 | 2;
    maxDaysAhead: number;
  };
  policy: CancellationPolicy;
  rulesText: Partial<Record<LocaleId, string>>;
  legalNotice?: string;
  inboxKey: { keyId: string; alg: 'hpke-v1'; pub: string };
  updatedAt: Timestamp;
}

/**
 * Function-only. The health-form template (the questions): not in the world-readable profile. Documents written before
 * D55 may still carry a `consent` map of texts; it is never read or returned, and the next `publishProfile` replaces
 * the whole document without it.
 */
export interface IntakeFormDoc {
  ownerUid: string;
  slug: string;
  formVersion: number;
  template: Record<string, unknown>;
  updatedAt: Timestamp;
}

export interface BusyEntry extends TimingFields {
  start: Timestamp;
  end: Timestamp;
  kind: 'appointment' | 'block';
}

/** Function-only: the scheduling rules and the no-show policy. */
export interface AvailabilityDoc {
  ownerUid: string;
  timeZoneID: string;
  weekly: { weekday: number; startMinutes: number; endMinutes: number }[];
  breaks: { weekday?: number; startMinutes: number; endMinutes: number }[];
  daysOff: { startDate: string; endDate: string }[];
  bufferMinutes: number;
  minNoticeHours: number;
  maxDaysAhead: number;
  /** D56: the grid of start times; 0 is "match the service". Absent means 15. */
  slotStepMinutes?: number;
  /** D56: "Keep my day compact". Absent means on. */
  compactDay?: boolean;
  busy: BusyEntry[];
  noShow: NoShowPolicy;
  reminderHourLocal: number;
  updatedAt: Timestamp;
}

export type BookingStatus = 'confirmed' | 'pendingApproval' | 'cancelledByClient' | 'cancelledByPro' | 'declined' | 'completed' | 'noShow';

/** Statuses that occupy time on the calendar. */
export const ACTIVE_BOOKING_STATUSES: readonly BookingStatus[] = ['confirmed', 'pendingApproval'];

export interface BookingDoc extends TimingFields {
  schemaVersion: 1;
  ownerUid: string;
  slug: string;
  status: BookingStatus;
  pendingReason?: PendingReason;
  serviceId: string;
  serviceName: string;
  durationMinutes: number;
  addOns: { id: string; name: string; minutes: number }[];
  guestCount: number;
  startsAt: Timestamp;
  endsAt: Timestamp;
  timeZoneID: string;
  client: { name: string; phone: string; email?: string; locale: LocaleId };
  phoneHash: string;
  emailHash?: string;
  note?: string;
  /** SHA-256 of each valid manage token (the token itself is never stored). At most five. */
  manageTokenHashes: string[];
  origin: 'bookingLink' | 'rebook' | 'waitlist';
  /** D47: the rules in force when the booking was made. Later edits by the professional never change them. */
  policy: CancellationPolicy;
  /** D47: the rule texts (per booking language) published at booking time. Absent on bookings made before the snapshot. */
  rulesText?: Partial<Record<LocaleId, string>>;
  /** D47: what the no-show policy meant for this client at booking time. Absent on bookings made before the snapshot. */
  noShowPolicy?: { isOn: boolean; limit: number; lateCancelCounts: boolean };
  clientConfirmedAt?: Timestamp;
  lateByMinutes?: number;
  lateReportedAt?: Timestamp;
  rescheduleCount: number;
  cancelledAt?: Timestamp;
  cancelledBy?: 'client' | 'professional';
  isLateCancellation?: boolean;
  cancelReason?: string;
  intakeSubmittedAt?: Timestamp;
  reminderSentAt?: Timestamp;
  /** The last thing the CLIENT did (set only by client-initiated updates). The booking trigger pushes on a change of it. */
  lastClientAction?: { kind: 'rescheduled' | 'confirmed' | 'late' | 'cancelled'; at: Timestamp };
  createdAt: Timestamp;
  updatedAt: Timestamp;
  /** endsAt + 7 days (D30). */
  purgeAt: Timestamp;
}

export interface HoldDoc extends TimingFields {
  ownerUid: string;
  slug: string;
  serviceId: string;
  addOnIds: string[];
  guests: number;
  startsAt: Timestamp;
  endsAt: Timestamp;
  expiresAt: Timestamp;
  holdKeyHash: string;
  kind: 'soft' | 'offer';
  waitlistId?: string;
  /** An offer made with "Suggest another time" on this (now declined) booking request. */
  suggestedForBookingId?: string;
}

export interface InboxItemDoc {
  ownerUid: string;
  bookingId: string;
  kind: 'intake' | 'checkin' | 'datarequest';
  keyId: string;
  sizeBytes: number;
  ctHash: string;
  createdAt: Timestamp;
  expiresAt: Timestamp;
  envelope?: { v: 1; suite: string; keyId: string; kind: string; itemId: string; enc: string; ct: string };
  storagePath?: string;
}

export interface PortalDoc {
  ownerUid: string;
  slug: string;
  clientRef: string;
  content: Record<string, unknown>;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  lastAccessAt?: Timestamp;
  expiresAt: Timestamp;
  revokedAt?: Timestamp;
}

export interface RescheduleRequestDoc {
  ownerUid: string;
  bookingId: string;
  clientName: string;
  serviceName: string;
  currentStart: Timestamp;
  currentEnd: Timestamp;
  requestedStart: Timestamp;
  requestedEnd: Timestamp;
  note?: string;
  status: 'pending' | 'accepted' | 'declined' | 'cancelled';
  createdAt: Timestamp;
  respondedAt?: Timestamp;
  purgeAt: Timestamp;
}

export interface WaitlistDoc {
  ownerUid: string;
  slug: string;
  name: string;
  phone: string;
  phoneHash: string;
  locale: LocaleId;
  serviceId?: string;
  serviceName?: string;
  dayFrom: string;
  dayTo: string;
  status: 'waiting' | 'offered' | 'booked';
  createdAt: Timestamp;
  offeredAt?: Timestamp;
  expiresAt: Timestamp;
}

export interface ContactDoc {
  ownerUid: string;
  phoneHash: string;
  /** This phone is one of her clients for the free-registration count (D42). */
  registered: boolean;
  registrationId?: string;
  bookingCount: number;
  lastIntakeAt?: Timestamp;
  marks: { id: string; at: Timestamp; kind: NoShowMark['kind'] }[];
  noShowResetAt?: Timestamp;
  onlineBookingStopped: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface DeviceDoc {
  fcmToken: string;
  platform: 'ios';
  locale?: LocaleId;
  lastSeenAt: Timestamp;
}

export interface EmailCodeDoc {
  codeHash: string;
  purpose: 'booking' | 'find';
  attempts: number;
  sentAt: Timestamp;
  expiresAt: Timestamp;
}

export interface EmailProofDoc {
  emailHash: string;
  expiresAt: Timestamp;
  usedAt?: Timestamp;
}

export interface IdempotencyDoc {
  bookingId: string;
  ownerUid: string;
  fingerprint: string;
  /** Hash of the email proof the booking was made with: a replay must show the same proof (or a fresh one). */
  proofHash?: string;
  expiresAt: Timestamp;
}

export interface RateDoc {
  count: number;
  expiresAt: Timestamp;
}

export interface AuditDoc {
  kind: 'inboxKeyChanged' | 'accountDeleted' | 'portalRevoked' | 'clientDataDeleted' | 'slugChanged';
  actor: string;
  at: Timestamp;
  expiresAt: Timestamp;
  keyId?: string;
}

export type { NoShowAction };
