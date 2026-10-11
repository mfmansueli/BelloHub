// A faithful stand-in for the Cloud Functions of firebase/functions/API.md (contract v1), for the Playwright suite and
// local development. It keeps everything in memory, applies the real rules (availability, policy, verification,
// approval, no-show protection, sealed inbox), answers the exact shapes and codes of API.md, and decrypts what the
// page seals with a test inbox key so a test can prove that what was typed is exactly what arrived, while the
// request body held only the envelope.
//
// Anything the mock enforces that the real functions do not is a test that proves nothing: keep the two in step.

import { createHash, randomBytes } from 'node:crypto';

import type {
  BookedResult,
  BookingActions,
  BookingOutcome,
  BookingPhase,
  BookingStatus,
  CreateBookingRequest,
  InboxKey,
  SealedEnvelope,
  VerificationProof,
  WireBooking,
  WireFormContext,
  WirePortal,
  WireProfile,
} from '../../src/api/types';
import { totals } from '../../src/app/booking/summary';
import { addDays, compareDateKeys, dayBounds, instantFromZoned, zonedDateKey } from '../../src/lib/datetime';
import { cancelMode, freeUntil, rescheduleMode, type PolicyValues } from '../../src/lib/policy';
import { decodeBase64Url } from '../../src/lib/base64url';
import { PAYLOAD_LIMITS, keyIdOf } from '../../src/crypto/envelope';
import { inboxKeyFromSeed, openEnvelope } from '../support/open';
import { SEED_INBOX_LABEL, scenarios, type Scenario } from './fixtures';
import { DEFAULT_RULES, freeSlots, isFree, type Busy, type SlotRules } from './slots';

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const EMAIL_CODE = '654321';
const MAX_RANGE_DAYS = 42;

/** The HTTP status and callable status of each code (API.md section 3). */
const CODES: Readonly<Record<string, { http: number; status: string }>> = {
  INVALID_ARGUMENT: { http: 400, status: 'INVALID_ARGUMENT' },
  UNAUTHENTICATED: { http: 401, status: 'UNAUTHENTICATED' },
  APP_CHECK_REQUIRED: { http: 401, status: 'UNAUTHENTICATED' },
  FORBIDDEN: { http: 403, status: 'PERMISSION_DENIED' },
  NOT_FOUND: { http: 404, status: 'NOT_FOUND' },
  TOKEN_EXPIRED: { http: 404, status: 'NOT_FOUND' },
  RATE_LIMITED: { http: 429, status: 'RESOURCE_EXHAUSTED' },
  VERIFICATION_FAILED: { http: 403, status: 'PERMISSION_DENIED' },
  VERIFICATION_REQUIRED: { http: 400, status: 'FAILED_PRECONDITION' },
  INVALID_CODE: { http: 400, status: 'INVALID_ARGUMENT' },
  NOT_ALLOWED: { http: 400, status: 'FAILED_PRECONDITION' },
  CONFIRMATION_REQUIRED: { http: 400, status: 'FAILED_PRECONDITION' },
  BOOKING_NOT_ACTIVE: { http: 400, status: 'FAILED_PRECONDITION' },
  SLUG_TAKEN: { http: 409, status: 'ALREADY_EXISTS' },
  KEY_MISMATCH: { http: 400, status: 'FAILED_PRECONDITION' },
  PAYLOAD_TOO_LARGE: { http: 400, status: 'INVALID_ARGUMENT' },
  CONFLICT: { http: 409, status: 'ABORTED' },
  NOT_CONFIGURED: { http: 503, status: 'UNAVAILABLE' },
  TRY_AGAIN: { http: 503, status: 'UNAVAILABLE' },
  INTERNAL: { http: 500, status: 'INTERNAL' },
};

export class MockError extends Error {
  readonly status: number;
  readonly callableStatus: string;

  constructor(
    readonly code: string,
    readonly details?: Record<string, unknown>,
    http?: number,
  ) {
    super(code);
    const known = CODES[code] ?? CODES['INTERNAL'] ?? { http: 500, status: 'INTERNAL' };
    this.status = http ?? known.http;
    this.callableStatus = known.status;
  }
}

interface StoredBooking {
  id: string;
  slug: string;
  status: BookingStatus;
  serviceId: string;
  addOnIds: string[];
  guests: number;
  startsAt: number;
  endsAt: number;
  durationMinutes: number;
  client: { name: string; phone: string; email?: string; locale: string };
  note?: string;
  policy: PolicyValues;
  rescheduleCount: number;
  clientConfirmedAt?: string;
  lateByMinutes?: number;
  pendingReschedule?: { requestedStart: string; status: 'pending' | 'declined' };
  intakeSubmittedAt?: string;
  /** "Confirm on WhatsApp" (API.md 5.8): an unverified request and the reference she quotes. */
  verification?: 'whatsapp';
  reference?: string;
}

/** A trusted-device token (API.md 5.8 `device`): one page, one address, 90 days. */
interface Device {
  slug: string;
  email: string;
  expiresAt: number;
}

interface Hold {
  id: string;
  slug: string;
  startsAt: number;
  endsAt: number;
  holdKey: string;
  expiresAt: number;
  /** A waiting-list offer (API.md 6.x `offerWaitlistSlot`): what the professional kept, for `getHold`. */
  offer?: { serviceId: string; addOnIds: string[]; guests: number };
}

interface Portal {
  slug: string;
  phone: string;
  name: string;
  /** What the server would answer to `rebook` for this client (approval or a pause still apply, API.md 5.13). */
  mode: 'direct' | 'approval' | 'paused';
}

export interface InboxItem {
  readonly slug: string;
  readonly bookingId: string;
  readonly kind: string;
  readonly itemId: string;
  readonly payload: Record<string, unknown>;
  readonly sizeBytes: number;
}

const token = (): string => randomBytes(16).toString('base64url');
/** API.md 5.8: five characters without look-alikes (no 0/O, 1/I/L). */
const referenceCode = (): string => [...randomBytes(5)].map((byte) => '23456789ABCDEFGHJKMNPQRSTUVWXYZ'[byte % 31] ?? '2').join('');
const sha = (text: string): Buffer => createHash('sha256').update(text).digest();
const iso = (ms: number): string => new Date(ms).toISOString();

/** The opaque template her app publishes (docs/10 section 5): the questions, each with a `kind`. */
const TEMPLATE = {
  questions: [
    {
      key: 'allergies',
      kind: 'multiChoice',
      label: { en: 'Any allergies?', 'pt-BR': 'Alguma alergia?', ar: 'هل لديك أي حساسية؟' },
      options: [
        { value: 'fragrance', label: { en: 'Fragrance', 'pt-BR': 'Fragrância', ar: 'العطور' } },
        { value: 'latex', label: { en: 'Latex', 'pt-BR': 'Látex', ar: 'اللاتكس' } },
        { value: 'nuts', label: { en: 'Nuts', 'pt-BR': 'Castanhas', ar: 'المكسرات' } },
        { value: 'retinol', label: { en: 'Retinol', 'pt-BR': 'Retinol', ar: 'الريتينول' } },
        { value: 'acids', label: { en: 'Acids', 'pt-BR': 'Ácidos', ar: 'الأحماض' } },
        { value: 'none', label: { en: 'None', 'pt-BR': 'Nenhuma', ar: 'لا شيء' } },
      ],
      required: true,
    },
    { key: 'medication', kind: 'yesNo', label: { en: 'Do you take any regular medication?', 'pt-BR': 'Você usa algum medicamento regularmente?', ar: 'هل تتناول أي دواء بانتظام؟' }, required: true },
    { key: 'pregnant', kind: 'yesNo', label: { en: 'Are you pregnant or breastfeeding?', 'pt-BR': 'Você está grávida ou amamentando?', ar: 'هل أنتِ حامل أو مرضعة؟' }, required: true, audience: 'adult' },
    { key: 'skinCondition', kind: 'yesNo', label: { en: 'Do you have a skin condition, such as eczema or rosacea?', 'pt-BR': 'Você tem alguma condição de pele, como eczema ou rosácea?', ar: 'هل لديك حالة جلدية مثل الإكزيما أو الوردية؟' }, required: true },
    { key: 'isotretinoin', kind: 'yesNo', label: { en: 'Have you taken isotretinoin or had a peel in the last 6 months?', 'pt-BR': 'Usou isotretinoína ou fez peeling nos últimos 6 meses?', ar: 'هل تناولتِ الإيزوتريتينوين أو أجريتِ تقشيرًا خلال آخر 6 أشهر؟' }, required: true },
    {
      key: 'anythingElse',
      kind: 'text',
      label: { en: 'Anything else the professional should know?', 'pt-BR': 'Mais alguma coisa que a profissional deva saber?', ar: 'هل هناك أي شيء آخر يجب أن تعرفه المختصة؟' },
      hint: { en: 'Optional. Skin that reacts easily, products you avoid, a recent procedure.' },
    },
  ],
} as const;

type Json = Record<string, unknown>;

function str(value: unknown, field: string): string {
  if (typeof value !== 'string' || value === '') throw new MockError('INVALID_ARGUMENT', { fields: [field] });
  return value;
}

function instant(value: unknown, field: string): number {
  const ms = Date.parse(str(value, field));
  if (!Number.isFinite(ms)) throw new MockError('INVALID_ARGUMENT', { fields: [field] });
  return ms;
}

function localDate(value: unknown, field: string): string {
  const text = str(value, field);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) throw new MockError('INVALID_ARGUMENT', { fields: [field] });
  return text;
}

function guestsOf(value: unknown): number {
  if (value === undefined) return 0;
  if (value !== 0 && value !== 1 && value !== 2) throw new MockError('INVALID_ARGUMENT', { fields: ['guests'] });
  return value;
}

function idsOf(value: unknown, field: string): string[] {
  if (value === undefined) return [];
  if (!Array.isArray(value) || !value.every((id) => typeof id === 'string')) throw new MockError('INVALID_ARGUMENT', { fields: [field] });
  return value;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const E164 = /^\+[1-9]\d{7,14}$/;

export class MockApi {
  private readonly scenarioBySlug = new Map<string, Scenario>();
  private readonly bookings = new Map<string, StoredBooking>();
  private readonly manageTokens = new Map<string, string>();
  private readonly portalTokens = new Map<string, Portal>();
  private readonly holds = new Map<string, Hold>();
  private readonly expiredTokens = new Set<string>();
  private readonly idempotent = new Map<string, { request: string; result: BookingOutcome }>();
  private readonly attempts = new Map<string, number>();
  private readonly items = new Map<string, string>();
  private readonly devices = new Map<string, Device>();
  /** Every `holdKey` a booking code was sent with (API.md 5.5), so a test can see the hold was stretched. */
  readonly codeHolds: string[] = [];
  readonly inbox: InboxItem[] = [];
  readonly waitlist: Json[] = [];
  readonly rescheduleRequests: Json[] = [];
  private readonly failures = new Map<string, { code: string; status: number; times: number }>();
  resendAfterSeconds = 30;
  private inboxSeed = new Uint8Array(sha(SEED_INBOX_LABEL));
  private inboxKey: InboxKey | null = null;

  constructor() {
    for (const scenario of scenarios()) this.scenarioBySlug.set(scenario.slug, scenario);
  }

  async init(): Promise<void> {
    this.inboxKey = (await inboxKeyFromSeed(this.inboxSeed)).publicKey;
  }

  reset(): void {
    this.bookings.clear();
    this.manageTokens.clear();
    this.portalTokens.clear();
    this.holds.clear();
    this.expiredTokens.clear();
    this.idempotent.clear();
    this.attempts.clear();
    this.items.clear();
    this.devices.clear();
    this.codeHolds.length = 0;
    this.inbox.length = 0;
    this.waitlist.length = 0;
    this.rescheduleRequests.length = 0;
    this.failures.clear();
    this.resendAfterSeconds = 30;
  }

  failNext(name: string, code: string, status: number, times = 1): void {
    this.failures.set(name, { code, status, times });
  }

  private maybeFail(name: string): void {
    const failure = this.failures.get(name);
    if (failure === undefined) return;
    failure.times -= 1;
    if (failure.times <= 0) this.failures.delete(name);
    throw new MockError(failure.code, undefined, failure.status);
  }

  // MARK: Lookups

  /**
   * A scenario by slug. `<scenario>-t<id>` is the same professional as `<scenario>` with a private set of
   * bookings, holds and lists (they are all keyed by slug), so parallel tests never share state without
   * a reset that would wipe the others.
   */
  private scenario(slug: string): Scenario {
    const found = this.scenarioBySlug.get(slug);
    if (found !== undefined) return found;
    const parent = /^(.+)-t[a-z0-9]{3,}$/.exec(slug)?.[1];
    const instance = parent === undefined ? undefined : this.scenarioBySlug.get(parent);
    if (instance === undefined) throw new MockError('NOT_FOUND');
    return instance;
  }

  private profile(slug: string): WireProfile {
    if (this.inboxKey === null) throw new Error('mock not initialised');
    return { ...this.scenario(slug).profile(this.inboxKey), slug };
  }

  private header(profile: WireProfile): WireBooking['professional'] {
    return {
      displayName: profile.displayName,
      ...(profile.businessName === undefined ? {} : { businessName: profile.businessName }),
      ...(profile.whatsappE164 === undefined ? {} : { whatsappE164: profile.whatsappE164 }),
    };
  }

  private bookingByToken(value: unknown, now = Date.now()): StoredBooking {
    const text = str(value, 'token');
    const id = this.manageTokens.get(text);
    const booking = id === undefined ? undefined : this.bookings.get(id);
    // An expired token and one that never existed carry no detail (API.md: `details` never holds personal data).
    if (booking === undefined) throw new MockError(this.expiredTokens.has(text) ? 'TOKEN_EXPIRED' : 'NOT_FOUND');
    if (booking.endsAt + 7 * DAY < now) throw new MockError('TOKEN_EXPIRED');
    return booking;
  }

  private busy(slug: string, now = Date.now()): Busy[] {
    const fromBookings = [...this.bookings.values()]
      .filter((b) => b.slug === slug && (b.status === 'confirmed' || b.status === 'pendingApproval'))
      .map((b): Busy => ({ startsAt: b.startsAt, endsAt: b.endsAt, bookingId: b.id }));
    const fromHolds = [...this.holds.values()].filter((h) => h.slug === slug && h.expiresAt > now).map((h): Busy => ({ startsAt: h.startsAt, endsAt: h.endsAt, holdKey: h.holdKey }));
    return [...fromBookings, ...fromHolds];
  }

  private rules(profile: WireProfile): SlotRules {
    return { ...DEFAULT_RULES, timeZone: profile.timeZoneID, maxDaysAhead: profile.booking.maxDaysAhead };
  }

  private duration(profile: WireProfile, serviceId: string, addOnIds: readonly string[], guests: number): number {
    const service = profile.services.find((s) => s.id === serviceId);
    if (service === undefined) throw new MockError('NOT_FOUND');
    return totals(service, profile.addOns.filter((a) => addOnIds.includes(a.id)), guests).totalMinutes;
  }

  private isPaused(profile: WireProfile, now: number): boolean {
    const until = profile.booking.pausedUntil === undefined ? null : Date.parse(profile.booking.pausedUntil);
    return !profile.booking.acceptingBookings || (until !== null && until > now);
  }

  private alternatives(slug: string, start: number, minutes: number, now: number, ignore?: { bookingId?: string; holdKey?: string }): string[] {
    const profile = this.profile(slug);
    return freeSlots(start, start + 5 * DAY, minutes, this.rules(profile), this.busy(slug, now), now, ignore).slice(0, 5);
  }

  // MARK: Views

  private phase(booking: StoredBooking, now: number): BookingPhase {
    if (now < booking.startsAt) return 'upcoming';
    if (now < booking.endsAt) return 'inProgress';
    return 'past';
  }

  private actions(booking: StoredBooking, now: number): BookingActions {
    const active = (booking.status === 'confirmed' || booking.status === 'pendingApproval') && now < booking.endsAt;
    const phase = this.phase(booking, now);
    const cancel = cancelMode(booking.startsAt, booking.policy, now);
    const resched = rescheduleMode(booking.startsAt, booking.policy, now, booking.rescheduleCount);
    const inside = now <= freeUntil(booking.startsAt, booking.policy);
    return {
      cancel: !active ? 'unavailable' : cancel === 'free' ? 'free' : cancel === 'allowLate' ? 'allowedWithWarning' : 'askByMessage',
      reschedule: !active || booking.status !== 'confirmed' || phase !== 'upcoming' ? 'unavailable' : resched,
      isInsideFreeWindow: inside,
      hoursUntilStart: Math.round(((booking.startsAt - now) / HOUR) * 100) / 100,
      cancellationWouldBeLate: !inside,
      canConfirmPresence: booking.status === 'confirmed' && booking.policy.askConfirmation && booking.clientConfirmedAt === undefined && phase === 'upcoming',
      canReportLate: booking.status === 'confirmed' && now >= booking.startsAt - 3 * HOUR && now < booking.endsAt,
    };
  }

  private view(booking: StoredBooking, now: number): WireBooking {
    const profile = this.profile(booking.slug);
    const service = profile.services.find((s) => s.id === booking.serviceId);
    if (service === undefined) throw new MockError('NOT_FOUND');
    const scenario = this.scenario(booking.slug);
    const addOns = profile.addOns.filter((a) => booking.addOnIds.includes(a.id));
    return {
      bookingId: booking.id,
      status: booking.status,
      phase: this.phase(booking, now),
      slug: booking.slug,
      professional: this.header(profile),
      service: { id: service.id, name: service.name },
      addOns: addOns.map((a) => ({ id: a.id, name: a.name, minutes: a.minutes })),
      guestCount: booking.guests,
      startsAt: iso(booking.startsAt),
      endsAt: iso(booking.endsAt),
      durationMinutes: booking.durationMinutes,
      timeZoneID: profile.timeZoneID,
      serverTime: iso(now),
      client: { name: booking.client.name },
      policy: booking.policy,
      rulesText: profile.rulesText,
      actions: this.actions(booking, now),
      ...(booking.clientConfirmedAt === undefined ? {} : { clientConfirmedAt: booking.clientConfirmedAt }),
      ...(booking.lateByMinutes === undefined ? {} : { lateByMinutes: booking.lateByMinutes }),
      rescheduleCount: booking.rescheduleCount,
      ...(booking.pendingReschedule === undefined ? {} : { pendingReschedule: booking.pendingReschedule }),
      intakeRequired: booking.intakeSubmittedAt === undefined && scenario.intakeCompleted !== true,
      tokenExpiresAt: iso(booking.endsAt + 7 * DAY),
    };
  }

  private booked(booking: StoredBooking, manageToken: string, profile: WireProfile): BookingOutcome {
    const service = profile.services.find((s) => s.id === booking.serviceId);
    return {
      status: booking.status === 'pendingApproval' ? 'pendingApproval' : 'confirmed',
      bookingId: booking.id,
      manageToken,
      startsAt: iso(booking.startsAt),
      endsAt: iso(booking.endsAt),
      timeZoneID: profile.timeZoneID,
      serviceName: service?.name ?? '',
      // An unverified request is never e-mailed when it is made (the address is not proven).
      emailSent: booking.client.email !== undefined && booking.verification === undefined,
      ...(booking.reference === undefined ? {} : { reference: booking.reference, requestExpiresAt: iso(Math.min(booking.startsAt, Date.now() + DAY)) }),
    };
  }

  // MARK: Public functions

  getPublicPage(input: Json, now = Date.now()): Json {
    this.maybeFail('getPublicPage');
    const slug = str(input['slug'], 'slug');
    const scenario = this.scenario(slug);
    return {
      profile: this.profile(slug),
      intakeAvailable: scenario.intakeAvailable !== false,
      features: { whatsAppAutomation: scenario.whatsAppAutomation === true, smsCallingCodes: ['55', '351', '966'] },
      serverTime: iso(now),
    };
  }

  getSlots(input: Json, now = Date.now()): Json {
    this.maybeFail('getSlots');
    const slug = str(input['slug'], 'slug');
    const profile = this.profile(slug);
    const from = localDate(input['from'], 'from');
    const to = localDate(input['to'], 'to');
    if (compareDateKeys(from, to) > 0 || compareDateKeys(addDays(from, MAX_RANGE_DAYS), to) < 0) throw new MockError('INVALID_ARGUMENT', { fields: ['to'] });
    const zone = profile.timeZoneID;
    let minutes: number;
    let ignore: { bookingId?: string; holdKey?: string } = {};
    let paused = false;
    if (typeof input['rescheduleToken'] === 'string') {
      // Moving a booked visit: its own time does not block it, and a pause does not stop it (D15).
      const booking = this.bookingByToken(input['rescheduleToken'], now);
      minutes = booking.durationMinutes;
      ignore = { bookingId: booking.id };
    } else {
      minutes = this.duration(profile, str(input['serviceId'], 'serviceId'), idsOf(input['addOnIds'], 'addOnIds'), guestsOf(input['guests']));
      if (typeof input['holdKey'] === 'string') ignore = { holdKey: input['holdKey'] };
      paused = this.isPaused(profile, now);
    }
    const days: { date: string; slots: string[] }[] = [];
    for (let day = from; compareDateKeys(day, to) <= 0; day = addDays(day, 1)) {
      const bounds = dayBounds(day, zone);
      days.push({ date: day, slots: paused ? [] : freeSlots(bounds.start, bounds.end, minutes, this.rules(profile), this.busy(slug, now), now, ignore) });
    }
    return { timeZoneID: zone, durationMinutes: minutes, paused, days };
  }

  holdSlot(input: Json, now = Date.now()): Json {
    this.maybeFail('holdSlot');
    const slug = str(input['slug'], 'slug');
    const profile = this.profile(slug);
    const holdKey = str(input['holdKey'], 'holdKey');
    if (holdKey.length < 16 || holdKey.length > 64) throw new MockError('INVALID_ARGUMENT', { fields: ['holdKey'] });
    const minutes = this.duration(profile, str(input['serviceId'], 'serviceId'), idsOf(input['addOnIds'], 'addOnIds'), guestsOf(input['guests']));
    const start = instant(input['startsAt'], 'startsAt');
    if (this.isPaused(profile, now)) return { status: 'paused' };
    if (!isFree(start, minutes, this.rules(profile), this.busy(slug, now), now, { holdKey })) {
      return { status: 'slotTaken', alternatives: this.alternatives(slug, start, minutes, now, { holdKey }) };
    }
    for (const hold of [...this.holds.values()]) if (hold.holdKey === holdKey) this.holds.delete(hold.id);
    const hold: Hold = { id: `h_${token()}`, slug, startsAt: start, endsAt: start + minutes * MINUTE, holdKey, expiresAt: now + 5 * MINUTE };
    this.holds.set(hold.id, hold);
    return { status: 'held', holdId: hold.id, expiresAt: iso(hold.expiresAt) };
  }

  /** 5.4: what a waiting-list offer link holds. Ordinary soft holds are not offers and stay unknown. */
  getHold(input: Json, now = Date.now()): Json {
    this.maybeFail('getHold');
    const slug = str(input['slug'], 'slug');
    this.profile(slug);
    const holdKey = str(input['holdKey'], 'holdKey');
    const hold = [...this.holds.values()].find((candidate) => candidate.slug === slug && candidate.holdKey === holdKey && candidate.offer !== undefined);
    if (hold?.offer === undefined) throw new MockError('NOT_FOUND');
    if (hold.expiresAt <= now) throw new MockError('TOKEN_EXPIRED');
    return { serviceId: hold.offer.serviceId, addOnIds: hold.offer.addOnIds, guests: hold.offer.guests, startsAt: iso(hold.startsAt), endsAt: iso(hold.endsAt), expiresAt: iso(hold.expiresAt) };
  }

  /**
   * Test control standing in for the owner's `offerWaitlistSlot`: holds `startsAt` (or the first free time from
   * tomorrow) for the first service and returns the link's key. `expired: true` makes an offer that already ended.
   */
  seedOffer(slug: string, options: { expired?: boolean } = {}, now = Date.now()): Json {
    const profile = this.profile(slug);
    const service = profile.services[0];
    if (service === undefined) throw new MockError('NOT_FOUND');
    const minutes = this.duration(profile, service.id, [], 0);
    const from = now + 24 * 60 * MINUTE;
    const start = this.alternatives(slug, from, minutes, now, {})[0];
    if (start === undefined) throw new MockError('NOT_FOUND');
    const startsAt = Date.parse(start);
    const holdKey = token();
    const hold: Hold = { id: `h_${token()}`, slug, startsAt, endsAt: startsAt + minutes * MINUTE, holdKey, expiresAt: options.expired === true ? now - MINUTE : now + 180 * MINUTE, offer: { serviceId: service.id, addOnIds: [], guests: 0 } };
    this.holds.set(hold.id, hold);
    return { holdKey, startsAt: iso(startsAt), serviceId: service.id };
  }

  sendEmailCode(input: Json, now = Date.now()): Json {
    this.maybeFail('sendEmailCode');
    const slug = str(input['slug'], 'slug');
    this.scenario(slug);
    const target = str(input['email'], 'email').trim().toLowerCase();
    this.attempts.set(`email:${target}`, 0);
    const holdKey = input['holdKey'];
    if (input['purpose'] === 'booking' && typeof holdKey === 'string') {
      // 5.5: a live soft hold under the key is stretched to the code's 10 minutes, never revived, never shortened.
      this.codeHolds.push(holdKey);
      for (const hold of this.holds.values()) {
        if (hold.slug === slug && hold.holdKey === holdKey && hold.offer === undefined && hold.expiresAt > now) hold.expiresAt = Math.max(hold.expiresAt, now + 10 * MINUTE);
      }
    }
    return { resendAfterSeconds: this.resendAfterSeconds, expiresInSeconds: 600 };
  }

  verifyEmailCode(input: Json): Json {
    const target = str(input['email'], 'email').trim().toLowerCase();
    const key = `email:${target}`;
    const tries = (this.attempts.get(key) ?? 0) + 1;
    this.attempts.set(key, tries);
    if (tries > 5) throw new MockError('RATE_LIMITED', { retryAfterSeconds: 600 });
    if (str(input['code'], 'code') !== EMAIL_CODE) throw new MockError('INVALID_CODE');
    // The real proof is an opaque single-use string; the mock's names its target so it can check the match.
    return { proof: `email:${target}`, expiresInSeconds: 1800 };
  }

  /** The e-mail a proof stands for, or VERIFICATION_FAILED. D46: the page only ever verifies an e-mail. */
  private verified(value: unknown): string {
    if (typeof value !== 'object' || value === null) throw new MockError('INVALID_ARGUMENT', { fields: ['verification'] });
    const proof = value as Partial<VerificationProof>;
    if (proof.method !== 'email' || typeof proof.proof !== 'string') throw new MockError('INVALID_ARGUMENT', { fields: ['verification'] });
    const [kind, ...rest] = proof.proof.split(':');
    if (kind !== 'email' || rest.length === 0) throw new MockError('VERIFICATION_FAILED');
    return rest.join(':');
  }

  /** How createBooking was verified (API.md 5.8): an e-mail proof, a trusted device, or nothing (`whatsapp`). */
  private bookingVerification(value: unknown, slug: string, email: string | undefined, now: number): 'email' | 'device' | 'whatsapp' {
    const method = typeof value === 'object' && value !== null ? (value as { method?: unknown }).method : undefined;
    if (method === 'whatsapp' || method === 'device') {
      if (email === undefined || email === '') throw new MockError('INVALID_ARGUMENT', { fields: ['client.email'] });
      if (method === 'whatsapp') return 'whatsapp';
      const device = this.devices.get(String((value as { token?: unknown }).token));
      if (device === undefined || device.slug !== slug || device.email !== email || device.expiresAt <= now) throw new MockError('VERIFICATION_FAILED');
      return 'device';
    }
    if (this.verified(value) !== email) throw new MockError('VERIFICATION_FAILED');
    return 'email';
  }

  /** 5.18: removes a trusted-device token; the same answer whether or not it existed. */
  forgetDevice(input: Json): Json {
    this.maybeFail('forgetDevice');
    this.devices.delete(str(input['token'], 'token'));
    return { ok: true };
  }

  /** Test control: a trusted device for `email` on `slug`, as if an earlier code-verified booking had made it. */
  seedDevice(slug: string, email: string, now = Date.now()): { token: string; expiresAt: string } {
    this.profile(slug);
    const value = token().slice(0, 22);
    this.devices.set(value, { slug, email: email.trim().toLowerCase(), expiresAt: now + 90 * DAY });
    return { token: value, expiresAt: iso(now + 90 * DAY) };
  }

  createBooking(input: Json, now = Date.now()): BookingOutcome {
    this.maybeFail('createBooking');
    const idempotencyKey = str(input['idempotencyKey'], 'idempotencyKey');
    if (!UUID.test(idempotencyKey)) throw new MockError('INVALID_ARGUMENT', { fields: ['idempotencyKey'] });
    const fingerprint = JSON.stringify({ ...input, idempotencyKey: undefined });
    const previous = this.idempotent.get(idempotencyKey);
    if (previous !== undefined) {
      if (previous.request !== fingerprint) throw new MockError('CONFLICT');
      return previous.result;
    }
    const slug = str(input['slug'], 'slug');
    const scenario = this.scenario(slug);
    const profile = this.profile(slug);
    const client = (typeof input['client'] === 'object' && input['client'] !== null ? input['client'] : {}) as Partial<CreateBookingRequest['client']>;
    const name = str(client.name, 'client.name');
    const phone = str(client.phone, 'client.phone');
    if (!E164.test(phone)) throw new MockError('INVALID_ARGUMENT', { fields: ['client.phone'] });
    const locale = str(client.locale, 'client.locale');
    const email = typeof client.email === 'string' ? client.email.trim().toLowerCase() : undefined;
    const note = input['note'];
    if (note !== undefined && (typeof note !== 'string' || note.length > 300)) throw new MockError('INVALID_ARGUMENT', { fields: ['note'] });
    for (const forbidden of ['firstVisit', 'heardFrom', 'hadBefore', 'guestNames', 'holdId', 'sessionKey']) {
      if (forbidden in input) throw new MockError('INVALID_ARGUMENT', { fields: [forbidden] });
    }
    const verification = this.bookingVerification(input['verification'], slug, email, now);
    if (verification === 'whatsapp' && profile.whatsappE164 === undefined) throw new MockError('NOT_ALLOWED');

    let result: BookingOutcome;
    const noShow = scenario.noShow[phone];
    if (this.isPaused(profile, now)) {
      result = { status: 'paused', ...(profile.booking.pausedUntil === undefined ? {} : { pausedUntil: profile.booking.pausedUntil }) };
    } else if (noShow === 'pauseOnline') {
      result = { status: 'paused' };
    } else {
      const serviceId = str(input['serviceId'], 'serviceId');
      const addOnIds = idsOf(input['addOnIds'], 'addOnIds');
      const guests = guestsOf(input['guests']);
      const minutes = this.duration(profile, serviceId, addOnIds, guests);
      const start = instant(input['startsAt'], 'startsAt');
      const holdKey = typeof input['holdKey'] === 'string' ? input['holdKey'] : undefined;
      if (!isFree(start, minutes, this.rules(profile), this.busy(slug, now), now, holdKey === undefined ? {} : { holdKey })) {
        result = { status: 'slotTaken', alternatives: this.alternatives(slug, start, minutes, now) };
      } else {
        const isKnown = scenario.knownClients.includes(phone) || [...this.bookings.values()].some((b) => b.slug === slug && b.client.phone === phone);
        const needsApproval = (profile.booking.requiresApproval && !isKnown) || noShow === 'approveNewBookings';
        // A trusted device never skips a look by the professional: the page goes back to the code.
        if (verification === 'device' && needsApproval) throw new MockError('VERIFICATION_REQUIRED');
        const unverified = verification === 'whatsapp';
        const stored: StoredBooking = {
          id: `bk_${token()}`,
          slug,
          status: needsApproval || unverified ? 'pendingApproval' : 'confirmed',
          ...(unverified ? { verification: 'whatsapp' as const, reference: referenceCode() } : {}),
          serviceId,
          addOnIds,
          guests,
          startsAt: start,
          endsAt: start + minutes * MINUTE,
          durationMinutes: minutes,
          client: { name, phone, locale, ...(email === undefined || email === '' ? {} : { email }) },
          ...(typeof note === 'string' && note !== '' ? { note } : {}),
          policy: profile.policy,
          rescheduleCount: 0,
        };
        this.bookings.set(stored.id, stored);
        if (holdKey !== undefined) for (const hold of [...this.holds.values()]) if (hold.holdKey === holdKey) this.holds.delete(hold.id);
        const manageToken = token();
        this.manageTokens.set(manageToken, stored.id);
        const booked = this.booked(stored, manageToken, profile) as BookedResult;
        if (verification === 'email' && stored.status === 'confirmed' && email !== undefined) {
          const device = this.seedDevice(slug, email, now);
          result = { ...booked, deviceToken: device.token, deviceTokenExpiresAt: device.expiresAt };
        } else {
          result = booked;
        }
      }
    }
    if (result.status !== 'slotTaken') this.idempotent.set(idempotencyKey, { request: fingerprint, result });
    return result;
  }

  joinWaitlist(input: Json): Json {
    this.maybeFail('joinWaitlist');
    const slug = str(input['slug'], 'slug');
    this.profile(slug);
    const entry = {
      slug,
      ...(typeof input['serviceId'] === 'string' ? { serviceId: input['serviceId'] } : {}),
      name: str(input['name'], 'name'),
      phone: str(input['phone'], 'phone'),
      locale: str(input['locale'], 'locale'),
      dayFrom: localDate(input['dayFrom'], 'dayFrom'),
      dayTo: localDate(input['dayTo'], 'dayTo'),
    };
    if (!E164.test(entry.phone)) throw new MockError('INVALID_ARGUMENT', { fields: ['phone'] });
    for (const forbidden of ['dateFrom', 'dateTo', 'email', 'note']) if (forbidden in input) throw new MockError('INVALID_ARGUMENT', { fields: [forbidden] });
    const same = this.waitlist.some((item) => item['slug'] === slug && item['phone'] === entry.phone && item['serviceId'] === entry.serviceId && item['dayFrom'] === entry.dayFrom && item['dayTo'] === entry.dayTo);
    if (!same) this.waitlist.push(entry);
    return { ok: true };
  }

  findBookings(input: Json, now = Date.now()): Json {
    this.maybeFail('findBookings');
    const slug = str(input['slug'], 'slug');
    this.profile(slug);
    const email = typeof input['email'] === 'string' ? input['email'].trim().toLowerCase() : undefined;
    if (this.verified(input['verification']) !== email) throw new MockError('VERIFICATION_FAILED');
    const mine = [...this.bookings.values()].filter((b) => b.slug === slug && b.endsAt > now && (b.status === 'confirmed' || b.status === 'pendingApproval') && b.client.email === email);
    return {
      bookings: mine
        .sort((a, b) => a.startsAt - b.startsAt)
        .map((b) => {
          const manageToken = token();
          this.manageTokens.set(manageToken, b.id);
          const view = this.view(b, now);
          return { bookingId: b.id, manageToken, serviceName: view.service.name, startsAt: view.startsAt, endsAt: view.endsAt, timeZoneID: view.timeZoneID, status: b.status };
        }),
    };
  }

  // MARK: Token functions

  getBooking(input: Json, now = Date.now()): WireBooking {
    this.maybeFail('getBooking');
    return this.view(this.bookingByToken(input['token'], now), now);
  }

  private active(booking: StoredBooking, now: number): StoredBooking {
    if (!(booking.status === 'confirmed' || booking.status === 'pendingApproval') || now >= booking.endsAt) throw new MockError('BOOKING_NOT_ACTIVE', { status: booking.status });
    return booking;
  }

  confirmPresence(input: Json, now = Date.now()): Json {
    this.maybeFail('confirmPresence');
    const booking = this.active(this.bookingByToken(input['token'], now), now);
    booking.clientConfirmedAt = iso(now);
    return { clientConfirmedAt: booking.clientConfirmedAt };
  }

  reportLate(input: Json, now = Date.now()): Json {
    this.maybeFail('reportLate');
    const booking = this.active(this.bookingByToken(input['token'], now), now);
    const minutes = input['minutes'];
    if (minutes !== 10 && minutes !== 15 && minutes !== 20 && minutes !== 30) throw new MockError('INVALID_ARGUMENT', { fields: ['minutes'] });
    booking.lateByMinutes = minutes;
    return { lateByMinutes: minutes, reportedAt: iso(now) };
  }

  rescheduleBooking(input: Json, now = Date.now()): Json {
    this.maybeFail('rescheduleBooking');
    const booking = this.active(this.bookingByToken(input['token'], now), now);
    if (this.actions(booking, now).reschedule !== 'direct') throw new MockError('NOT_ALLOWED', { action: this.actions(booking, now).reschedule === 'request' ? 'request' : 'message' });
    const profile = this.profile(booking.slug);
    const start = instant(input['startsAt'], 'startsAt');
    if (!isFree(start, booking.durationMinutes, this.rules(profile), this.busy(booking.slug, now), now, { bookingId: booking.id })) {
      return { status: 'slotTaken', alternatives: this.alternatives(booking.slug, start, booking.durationMinutes, now, { bookingId: booking.id }) };
    }
    booking.startsAt = start;
    booking.endsAt = start + booking.durationMinutes * MINUTE;
    booking.rescheduleCount += 1;
    delete booking.pendingReschedule;
    return { status: 'moved', startsAt: iso(booking.startsAt), endsAt: iso(booking.endsAt), rescheduleCount: booking.rescheduleCount };
  }

  requestReschedule(input: Json, now = Date.now()): Json {
    this.maybeFail('requestReschedule');
    const booking = this.active(this.bookingByToken(input['token'], now), now);
    if (this.actions(booking, now).reschedule !== 'request') throw new MockError('NOT_ALLOWED', { action: this.actions(booking, now).reschedule === 'direct' ? 'direct' : 'message' });
    const profile = this.profile(booking.slug);
    const start = instant(input['startsAt'], 'startsAt');
    const note = input['note'];
    if (note !== undefined && (typeof note !== 'string' || note.length > 300)) throw new MockError('INVALID_ARGUMENT', { fields: ['note'] });
    if (!isFree(start, booking.durationMinutes, this.rules(profile), this.busy(booking.slug, now), now, { bookingId: booking.id })) {
      return { status: 'slotTaken', alternatives: this.alternatives(booking.slug, start, booking.durationMinutes, now, { bookingId: booking.id }) };
    }
    booking.pendingReschedule = { requestedStart: iso(start), status: 'pending' };
    this.rescheduleRequests.push({ slug: booking.slug, bookingId: booking.id, startsAt: iso(start), ...(typeof note === 'string' ? { note } : {}) });
    return { status: 'requested' };
  }

  cancelBooking(input: Json, now = Date.now()): Json {
    this.maybeFail('cancelBooking');
    const booking = this.active(this.bookingByToken(input['token'], now), now);
    const reason = input['reason'];
    if (reason !== undefined && (typeof reason !== 'string' || reason.length > 200)) throw new MockError('INVALID_ARGUMENT', { fields: ['reason'] });
    const verdict = this.actions(booking, now).cancel;
    if (verdict === 'askByMessage' || verdict === 'unavailable') throw new MockError('NOT_ALLOWED', { action: 'message' });
    if (verdict === 'allowedWithWarning' && input['acceptLateWarning'] !== true) throw new MockError('CONFIRMATION_REQUIRED');
    booking.status = 'cancelledByClient';
    return { status: 'cancelled', isLateCancellation: verdict === 'allowedWithWarning' };
  }

  // MARK: Portal

  seedPortal(slug: string, name: string, phone: string, mode: Portal['mode'] = 'direct'): string {
    this.scenario(slug);
    const value = token();
    this.portalTokens.set(value, { slug, phone, name, mode });
    return value;
  }

  getPortal(input: Json, now = Date.now()): WirePortal {
    this.maybeFail('getPortal');
    const portal = this.portalTokens.get(str(input['token'], 'token'));
    if (portal === undefined) throw new MockError(this.expiredTokens.has(String(input['token'])) ? 'TOKEN_EXPIRED' : 'NOT_FOUND');
    const profile = this.profile(portal.slug);
    const mine = [...this.bookings.values()].filter((b) => b.slug === portal.slug && b.client.phone === portal.phone);
    const upcoming = mine.filter((b) => b.status === 'confirmed' && b.endsAt > now).sort((a, b) => a.startsAt - b.startsAt);
    const past = mine.filter((b) => b.status === 'confirmed' && b.endsAt <= now).sort((a, b) => b.startsAt - a.startsAt);
    const serviceName = (id: string): string => profile.services.find((s) => s.id === id)?.name ?? '';
    const service = profile.services[1] ?? profile.services[0];
    if (service === undefined) throw new MockError('NOT_FOUND');
    const recommended = zonedDateKey(now + 28 * DAY, profile.timeZoneID);
    return {
      slug: portal.slug,
      professional: this.header(profile),
      clientName: portal.name,
      upcoming: upcoming.map((b) => ({ serviceName: serviceName(b.serviceId), startsAt: iso(b.startsAt), endsAt: iso(b.endsAt), timeZoneID: profile.timeZoneID })),
      next: { serviceName: service.name, recommendedDate: recommended },
      past: past.map((b) => ({ serviceName: serviceName(b.serviceId), date: zonedDateKey(b.startsAt, profile.timeZoneID), summary: 'Your skin responded well. Keep products gentle and fragrance-free.' })),
      aftercare: past.length === 0 ? [] : [{ title: service.name, lines: ['Use only a gentle, fragrance-free cleanser tonight.', 'Wear sunscreen in the morning.', 'Message Maria if anything feels uncomfortable.'], date: zonedDateKey(past[0]?.startsAt ?? now, profile.timeZoneID) }],
      products: [{ name: 'Calming serum', note: 'Used in your treatment' }],
      rebook: { serviceId: service.id, addOnIds: [] },
      expiresAt: iso(now + 180 * DAY),
    };
  }

  rebook(input: Json, now = Date.now()): BookingOutcome {
    this.maybeFail('rebook');
    const value = str(input['token'], 'token');
    const idempotencyKey = str(input['idempotencyKey'], 'idempotencyKey');
    if (!UUID.test(idempotencyKey)) throw new MockError('INVALID_ARGUMENT', { fields: ['idempotencyKey'] });
    const fingerprint = JSON.stringify({ ...input, idempotencyKey: undefined });
    const previous = this.idempotent.get(idempotencyKey);
    if (previous !== undefined) {
      if (previous.request !== fingerprint) throw new MockError('CONFLICT');
      return previous.result;
    }
    const portal = this.portalTokens.get(value);
    let slug: string;
    let client: StoredBooking['client'];
    let serviceId: string;
    let addOnIds: string[];
    let mode: Portal['mode'];
    if (portal !== undefined) {
      slug = portal.slug;
      client = { name: portal.name, phone: portal.phone, locale: 'en' };
      serviceId = typeof input['serviceId'] === 'string' ? input['serviceId'] : 'brazilian';
      addOnIds = idsOf(input['addOnIds'], 'addOnIds');
      mode = portal.mode;
    } else {
      const base = this.bookingByToken(value, now);
      slug = base.slug;
      client = base.client;
      serviceId = typeof input['serviceId'] === 'string' ? input['serviceId'] : base.serviceId;
      addOnIds = input['addOnIds'] === undefined ? base.addOnIds : idsOf(input['addOnIds'], 'addOnIds');
      mode = this.scenario(slug).noShow[client.phone] === 'pauseOnline' ? 'paused' : this.scenario(slug).noShow[client.phone] === 'approveNewBookings' ? 'approval' : 'direct';
    }
    const profile = this.profile(slug);
    let result: BookingOutcome;
    if (mode === 'paused' || this.isPaused(profile, now)) {
      result = { status: 'paused', ...(profile.booking.pausedUntil === undefined ? {} : { pausedUntil: profile.booking.pausedUntil }) };
    } else {
      const minutes = this.duration(profile, serviceId, addOnIds, 0);
      const start = instant(input['startsAt'], 'startsAt');
      if (!isFree(start, minutes, this.rules(profile), this.busy(slug, now), now)) {
        result = { status: 'slotTaken', alternatives: this.alternatives(slug, start, minutes, now) };
      } else {
        const stored: StoredBooking = {
          id: `bk_${token()}`,
          slug,
          status: mode === 'approval' ? 'pendingApproval' : 'confirmed',
          serviceId,
          addOnIds,
          guests: 0,
          startsAt: start,
          endsAt: start + minutes * MINUTE,
          durationMinutes: minutes,
          client,
          policy: profile.policy,
          rescheduleCount: 0,
          intakeSubmittedAt: iso(now - 30 * DAY),
        };
        this.bookings.set(stored.id, stored);
        const manageToken = token();
        this.manageTokens.set(manageToken, stored.id);
        result = this.booked(stored, manageToken, profile);
      }
    }
    if (result.status !== 'slotTaken') this.idempotent.set(idempotencyKey, { request: fingerprint, result });
    return result;
  }

  // MARK: Sealed forms

  getFormContext(input: Json, now = Date.now()): WireFormContext {
    this.maybeFail('getFormContext');
    if (this.inboxKey === null) throw new Error('mock not initialised');
    const booking = this.bookingByToken(input['token'], now);
    const scenario = this.scenario(booking.slug);
    if (scenario.intakeAvailable === false) throw new MockError('NOT_FOUND');
    const profile = this.profile(booking.slug);
    return {
      bookingId: booking.id,
      professional: { displayName: profile.displayName },
      formVersion: 1,
      template: TEMPLATE,
      inboxKey: this.inboxKey,
      intakeCompletedWithinMonths: booking.intakeSubmittedAt !== undefined || scenario.intakeCompleted === true,
    };
  }

  async submitSealed(input: Json, now = Date.now()): Promise<Json> {
    this.maybeFail('submitSealed');
    if (this.inboxKey === null) throw new Error('mock not initialised');
    const booking = this.bookingByToken(input['token'], now);
    const envelope = input['envelope'] as Partial<SealedEnvelope> | undefined;
    if (envelope === undefined || envelope.v !== 1 || envelope.suite !== 'hpke-x25519-hkdf-sha256-chacha20poly1305') throw new MockError('INVALID_ARGUMENT', { fields: ['envelope'] });
    if (envelope.kind !== 'intake' && envelope.kind !== 'checkin' && envelope.kind !== 'datarequest') throw new MockError('INVALID_ARGUMENT', { fields: ['envelope.kind'] });
    if (typeof envelope.itemId !== 'string' || !UUID.test(envelope.itemId) || typeof envelope.enc !== 'string' || typeof envelope.ct !== 'string') throw new MockError('INVALID_ARGUMENT', { fields: ['envelope'] });
    if (envelope.keyId !== this.inboxKey.keyId) throw new MockError('KEY_MISMATCH');
    const maxBytes = PAYLOAD_LIMITS[envelope.kind] + 1024;
    const ctBytes = decodeBase64Url(envelope.ct).length;
    if (ctBytes > maxBytes) throw new MockError('PAYLOAD_TOO_LARGE', { maxBytes });
    const seen = this.items.get(envelope.itemId);
    if (seen !== undefined) {
      // The same bytes again is a retry; different bytes under the same id is a conflict.
      if (seen !== envelope.ct) throw new MockError('CONFLICT');
      return { ok: true };
    }
    // The server never sees the answers. This stand-in opens the envelope only so a test can compare it to what was typed.
    let text: string;
    try {
      text = await openEnvelope(envelope as SealedEnvelope, this.inboxSeed);
    } catch {
      throw new MockError('INVALID_ARGUMENT', { fields: ['envelope.ct'] });
    }
    this.items.set(envelope.itemId, envelope.ct);
    this.inbox.push({ slug: booking.slug, bookingId: booking.id, kind: envelope.kind, itemId: envelope.itemId, payload: JSON.parse(text) as Json, sizeBytes: ctBytes });
    if (envelope.kind === 'intake') booking.intakeSubmittedAt = iso(now);
    return { ok: true };
  }

  // MARK: Test controls

  seedBooking(
    input: { slug: string; startsInMinutes: number; status?: BookingStatus | 'completed'; serviceId?: string; phone?: string; email?: string; name?: string; rescheduleCount?: number; intake?: 'pending' | 'done'; guests?: number; policy?: Partial<PolicyValues> },
    now = Date.now(),
  ): { token: string; bookingId: string; portalToken: string } {
    const profile = this.profile(input.slug);
    const serviceId = input.serviceId ?? 'brazilian';
    const guests = input.guests ?? 0;
    const minutes = this.duration(profile, serviceId, [], guests);
    const start = now + input.startsInMinutes * MINUTE;
    const stored: StoredBooking = {
      id: `bk_${token()}`,
      slug: input.slug,
      // "completed" is a confirmed visit in the past (the API has no such status: `phase` says it).
      status: input.status === 'completed' ? 'confirmed' : (input.status ?? 'confirmed'),
      serviceId,
      addOnIds: [],
      guests,
      startsAt: start,
      endsAt: start + minutes * MINUTE,
      durationMinutes: minutes,
      client: { name: input.name ?? 'Helena Duarte', phone: input.phone ?? '+5511987654321', email: input.email ?? 'helena@example.com', locale: 'en' },
      policy: { ...profile.policy, ...input.policy },
      rescheduleCount: input.rescheduleCount ?? 0,
      ...(input.intake === 'done' ? { intakeSubmittedAt: iso(now - 20 * DAY) } : {}),
    };
    this.bookings.set(stored.id, stored);
    const manageToken = token();
    this.manageTokens.set(manageToken, stored.id);
    const portalToken = this.seedPortal(input.slug, (input.name ?? 'Helena Duarte').split(/\s+/)[0] ?? 'Helena', stored.client.phone);
    return { token: manageToken, bookingId: stored.id, portalToken };
  }

  /** What the server holds for a professional's bookings, so a test can compare it with what the page showed. */
  listBookings(slug: string): Json[] {
    return [...this.bookings.values()]
      .filter((booking) => booking.slug === slug)
      .map((booking) => ({
        id: booking.id,
        status: booking.status,
        serviceId: booking.serviceId,
        addOnIds: booking.addOnIds,
        guests: booking.guests,
        startsAt: iso(booking.startsAt),
        durationMinutes: booking.durationMinutes,
        client: booking.client,
        note: booking.note ?? null,
        verification: booking.verification ?? null,
        reference: booking.reference ?? null,
        rescheduleCount: booking.rescheduleCount,
        clientConfirmedAt: booking.clientConfirmedAt ?? null,
        lateByMinutes: booking.lateByMinutes ?? null,
        intake: booking.intakeSubmittedAt === undefined ? 'pending' : 'done',
      }));
  }

  seedExpired(slug: string): string {
    this.scenario(slug);
    const value = token();
    this.expiredTokens.add(value);
    return value;
  }

  async keyId(): Promise<string> {
    const { publicKey } = await inboxKeyFromSeed(this.inboxSeed);
    return keyIdOf(decodeBase64Url(publicKey.pub));
  }

  freeUntilFor(bookingId: string): string | null {
    const booking = this.bookings.get(bookingId);
    return booking === undefined ? null : iso(freeUntil(booking.startsAt, booking.policy));
  }

  dayKey(slug: string, instantMs: number): string {
    return zonedDateKey(instantMs, this.profile(slug).timeZoneID);
  }

  instantAt(slug: string, day: string, hour: number, minute: number): number {
    return instantFromZoned(day, hour, minute, this.profile(slug).timeZoneID);
  }
}
