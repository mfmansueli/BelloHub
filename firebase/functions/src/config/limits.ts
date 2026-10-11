// Every cap and rate limit of the server in one file, so they can be reviewed together (docs/11 section 6).
// A limit is `{ limit, windowSeconds }`: at most `limit` calls in a fixed window.

export interface RateLimit {
  readonly limit: number;
  readonly windowSeconds: number;
}

const perMinute = (limit: number): RateLimit => ({ limit, windowSeconds: 60 });
const perHour = (limit: number): RateLimit => ({ limit, windowSeconds: 3600 });
const perDay = (limit: number): RateLimit => ({ limit, windowSeconds: 86_400 });

export const RATE = {
  publicPageIp: perMinute(120),
  slotsIp: perMinute(60),
  holdIp: perHour(20),
  emailCodeEmail: perHour(5),
  emailCodeIp: perHour(10),
  emailCodeOwnerDay: perDay(300),
  emailCodeVerifyEmail: perHour(10),
  createBookingIp: perHour(10),
  createBookingPhone: perHour(5),
  createBookingOwnerDay: perDay(300),
  /** "I didn't get the code": unverified requests confirmed on WhatsApp (no proof, so tighter than createBooking). */
  unverifiedIp: perDay(5),
  unverifiedEmail: perDay(3),
  unverifiedPhone: perDay(3),
  unverifiedOwnerDay: perDay(50),
  /** "Forget this device". */
  forgetDeviceIp: perHour(20),
  /** Emails about bookings (confirmation, approval, change) per professional, to protect cost and sender reputation. */
  bookingEmailOwnerDay: perDay(500),
  findBookingsIp: perHour(10),
  findBookingsPhone: perHour(5),
  waitlistIp: perHour(5),
  waitlistPhoneDay: perDay(3),
  tokenCallsToken: perMinute(60),
  tokenCallsIp: perMinute(120),
  tokenActionsToken: perHour(20),
  sealedBooking: perHour(5),
  sealedIp: perHour(20),
  icsIp: perMinute(30),
  slugCheckOwner: perMinute(30),
  publishOwner: perMinute(30),
  mailboxOwner: perMinute(120),
  ownerCalls: perMinute(120),
  /** "Message <client>" asks for the client's own manage link (`mintManageLink`). */
  manageLinkOwner: perHour(60),
  deleteOwnerDay: perDay(20)
} as const;

/** Seconds between two verification emails to the same address. */
export const EMAIL_RESEND_SECONDS = 30;
/** A code lasts 30 minutes: an e-mail can be slow, and a late code is still the same person's code (5 tries). */
export const EMAIL_CODE_TTL_SECONDS = 1800;
/** The soft hold under a booking code is stretched to this, not to the code's life: a slot is not kept for 30 minutes. */
export const EMAIL_CODE_HOLD_SECONDS = 600;
export const EMAIL_CODE_MAX_ATTEMPTS = 5;
export const EMAIL_PROOF_TTL_SECONDS = 1800;
/** A phone sign-in older than this is not accepted as proof (docs/10 section 3). */
export const PHONE_AUTH_MAX_AGE_SECONDS = 600;

export const MAX_MANAGE_TOKENS_PER_BOOKING = 5;
/** `mintManageLink` returns the same link for this long, so opening the message sheet twice does not use up a token. */
export const MANAGE_LINK_REUSE_MINUTES = 30;
/** An unverified (WhatsApp) request waits at most this long for her answer, then the time is released. */
export const UNVERIFIED_REQUEST_HOURS = 24;
/** Unverified requests one phone or one e-mail may have waiting with one professional at the same time. */
export const MAX_PENDING_UNVERIFIED_PER_CONTACT = 2;
/** A trusted-device token (returning clients skip the code) lives this long and is never renewed. */
export const TRUSTED_DEVICE_DAYS = 90;
/** Trusted devices kept per e-mail and page; a new one replaces the oldest. */
export const MAX_TRUSTED_DEVICES = 5;
/** Sealed items one booking may leave in the mailbox before the app acknowledges them (a cap on what one link can cost). */
export const MAX_SEALED_PER_BOOKING = 20;
export const MAX_RANGE_DAYS = 42;
export const MAX_ALTERNATIVES = 5;
export const ALTERNATIVES_SEARCH_DAYS = 14;
export const MAX_WAITING_PER_OWNER = 100;
export const OFFER_DEFAULT_MINUTES = 180;

export const SIZE = {
  intakeBytes: 256 * 1024,
  checkinBytes: 3 * 1024 * 1024,
  dataRequestBytes: 8 * 1024,
  /** Envelope overhead allowed on top of the plaintext cap: padding, the 16 byte tag. */
  envelopeSlackBytes: 1024,
  /** Above this an envelope goes to Cloud Storage instead of Firestore (docs/11 section 2). */
  inlineBytes: 200 * 1024,
  profileBytes: 700 * 1024,
  photoBytes: 120 * 1024,
  intakeTemplateBytes: 200 * 1024,
  portalBytes: 64 * 1024
} as const;

/** Rows handled per cleanup pass; the job loops until a pass finds nothing. */
export const CLEANUP_BATCH = 200;
