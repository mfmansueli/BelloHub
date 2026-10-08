// A faithful stand-in for the Cloud Functions of docs/11 section 3, for the Playwright suite and local development.
// It keeps everything in memory, applies the real rules (availability, policy, verification, approval, no-show
// protection, sealed inbox), and decrypts what the page seals with a test inbox key so a test can prove that what
// was typed is exactly what arrived, while the request body held only the envelope.
//
// Contract assumptions made here are the page's (src/api/types.ts); firebase/functions/API.md is reconciled later.

import { randomBytes } from 'node:crypto';

import type {
  BookingResult,
  BookingStatus,
  BookingView,
  CreateBookingRequest,
  FormContext,
  FormQuestion,
  InboxKey,
  PortalView,
  ProfessionalLite,
  PublicProfile,
  SealedEnvelope,
  VerificationProof,
} from '../../src/api/types';
import { totals } from '../../src/app/booking/summary';
import { instantFromZoned, zonedDateKey } from '../../src/lib/datetime';
import { cancelMode, freeUntil, rescheduleMode, type PolicyValues } from '../../src/lib/policy';
import { decodeBase64Url } from '../../src/lib/base64url';
import { PAYLOAD_LIMITS, keyIdOf } from '../../src/crypto/envelope';
import { inboxKeyFromSeed, openEnvelope } from '../support/open';
import { createHash } from 'node:crypto';
import { SEED_INBOX_LABEL, scenarios, type Scenario } from './fixtures';
import { DEFAULT_RULES, freeSlots, isFree, type Busy, type SlotRules } from './slots';

const MINUTE = 60_000;
const SMS_CODE = '123456';
const EMAIL_CODE = '654321';

export class MockError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
    readonly extra: Record<string, unknown> = {},
  ) {
    super(code);
  }
}

interface StoredBooking {
  id: string;
  slug: string;
  status: BookingStatus;
  serviceId: string;
  addOnIds: string[];
  guestNames: string[];
  startsAt: number;
  endsAt: number;
  totalMinutes: number;
  client: { name: string; phone: string; email?: string; locale: string };
  policy: PolicyValues;
  rescheduleCount: number;
  clientConfirmedAt?: string;
  lateByMinutes?: number;
  proReply?: string;
  rescheduleRequest?: { requestedStart: string };
  movedFrom?: string;
  intake: 'pending' | 'done' | 'notNeeded';
  checkIn: 'available' | 'none';
  idempotencyKey?: string;
}

interface Hold {
  id: string;
  slug: string;
  startsAt: number;
  endsAt: number;
  sessionKey: string;
  expiresAt: number;
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
const sha = (text: string): Buffer => createHash('sha256').update(text).digest();

const QUESTIONS: readonly FormQuestion[] = [
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
];

export class MockApi {
  private readonly scenarioBySlug = new Map<string, Scenario>();
  private readonly bookings = new Map<string, StoredBooking>();
  private readonly manageTokens = new Map<string, string>();
  private readonly portalTokens = new Map<string, { slug: string; phone: string; name: string; mode: PortalView['rebookMode'] }>();
  private readonly holds = new Map<string, Hold>();
  private readonly expiredTokens = new Map<string, string>();
  private readonly idempotent = new Map<string, BookingResult>();
  private readonly attempts = new Map<string, number>();
  private readonly itemIds = new Set<string>();
  readonly inbox: InboxItem[] = [];
  readonly waitlist: Record<string, unknown>[] = [];
  readonly rescheduleRequests: Record<string, unknown>[] = [];
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
    this.itemIds.clear();
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
    throw new MockError(failure.code, failure.status);
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
    if (instance === undefined) throw new MockError('notFound', 404);
    return instance;
  }

  private profile(slug: string): PublicProfile {
    if (this.inboxKey === null) throw new Error('mock not initialised');
    return { ...this.scenario(slug).profile(this.inboxKey), slug };
  }

  private lite(profile: PublicProfile): ProfessionalLite {
    const { slug, displayName, firstName, photo, whatsappE164, locales, defaultLocale, regionCode, timeZoneID, currencyCode, city, weekStart, use24Hour } = profile;
    return { slug, displayName, firstName, locales, defaultLocale, regionCode, timeZoneID, currencyCode, ...(photo === undefined ? {} : { photo }), ...(whatsappE164 === undefined ? {} : { whatsappE164 }), ...(city === undefined ? {} : { city }), ...(weekStart === undefined ? {} : { weekStart }), ...(use24Hour === undefined ? {} : { use24Hour }) };
  }

  private bookingByToken(value: string): StoredBooking {
    const id = this.manageTokens.get(value);
    const booking = id === undefined ? undefined : this.bookings.get(id);
    if (booking === undefined) {
      // A portal token also opens the client's latest booking for the pages that only need the professional.
      const portal = this.portalTokens.get(value);
      if (portal !== undefined) {
        const latest = [...this.bookings.values()].filter((b) => b.slug === portal.slug && b.client.phone === portal.phone).sort((a, b) => b.startsAt - a.startsAt)[0];
        if (latest !== undefined) return latest;
      }
      const expiredFor = this.expiredTokens.get(value);
      // An expired link names who to message; a link that never existed does not.
      if (expiredFor !== undefined) throw new MockError('expired', 410, { professional: this.lite(this.profile(expiredFor)) });
      throw new MockError('notFound', 404);
    }
    return booking;
  }

  private busy(slug: string, ignore?: { sessionKey?: string; bookingId?: string }, now = Date.now()): Busy[] {
    const fromBookings = [...this.bookings.values()]
      .filter((b) => b.slug === slug && (b.status === 'confirmed' || b.status === 'pendingApproval'))
      .map((b): Busy => ({ startsAt: b.startsAt, endsAt: b.endsAt, bookingId: b.id }));
    const fromHolds = [...this.holds.values()].filter((h) => h.slug === slug && h.expiresAt > now).map((h): Busy => ({ startsAt: h.startsAt, endsAt: h.endsAt, sessionKey: h.sessionKey }));
    void ignore;
    return [...fromBookings, ...fromHolds];
  }

  private rules(profile: PublicProfile): SlotRules {
    return { ...DEFAULT_RULES, timeZone: profile.timeZoneID, maxDaysAhead: profile.booking.maxDaysAhead };
  }

  private duration(profile: PublicProfile, serviceId: string, addOnIds: readonly string[], guests: number): number {
    const service = profile.services.find((s) => s.id === serviceId);
    if (service === undefined) throw new MockError('invalidInput', 400);
    return totals(service, profile.addOns.filter((a) => addOnIds.includes(a.id)), guests).totalMinutes;
  }

  // MARK: Views

  private view(booking: StoredBooking, now: number): BookingView {
    const profile = this.profile(booking.slug);
    const service = profile.services.find((s) => s.id === booking.serviceId);
    if (service === undefined) throw new MockError('notFound', 404);
    const addOns = profile.addOns.filter((a) => booking.addOnIds.includes(a.id));
    const sum = totals(service, addOns, booking.guestNames.length);
    return {
      id: booking.id,
      status: booking.status,
      service: { id: service.id, name: service.name, durationMinutes: service.durationMinutes },
      addOns: addOns.map((a) => ({ id: a.id, name: a.name, minutes: a.minutes })),
      guestCount: booking.guestNames.length,
      ...(booking.guestNames.some(Boolean) ? { guestNames: booking.guestNames } : {}),
      startsAt: new Date(booking.startsAt).toISOString(),
      endsAt: new Date(booking.endsAt).toISOString(),
      totalMinutes: sum.totalMinutes,
      ...(sum.price === null ? {} : { price: sum.price.kind === 'onRequest' ? { display: 'onRequest' as const, currency: profile.currencyCode } : { display: sum.price.kind === 'amount' ? ('show' as const) : ('startingFrom' as const), amount: sum.price.amount, currency: profile.currencyCode } }),
      professional: this.lite(profile),
      client: { firstName: booking.client.name.split(/\s+/)[0] ?? booking.client.name },
      rules: profile.rules,
      policy: booking.policy,
      rescheduleCount: booking.rescheduleCount,
      ...(booking.clientConfirmedAt === undefined ? {} : { clientConfirmedAt: booking.clientConfirmedAt }),
      ...(booking.lateByMinutes === undefined ? {} : { lateByMinutes: booking.lateByMinutes }),
      ...(booking.proReply === undefined ? {} : { proReply: booking.proReply }),
      ...(booking.rescheduleRequest === undefined ? {} : { rescheduleRequest: booking.rescheduleRequest }),
      ...(booking.movedFrom === undefined ? {} : { movedFrom: booking.movedFrom }),
      forms: { intake: booking.intake, checkIn: booking.checkIn },
      serverNow: new Date(now).toISOString(),
    };
  }

  // MARK: Public functions

  getPublicPage(slug: string): PublicProfile {
    this.maybeFail('getPublicPage');
    return this.profile(slug);
  }

  getSlots(query: Record<string, unknown>, now = Date.now()): { slots: string[]; durationMinutes: number } {
    this.maybeFail('getSlots');
    const from = Date.parse(String(query['from']));
    const to = Date.parse(String(query['to']));
    if (!Number.isFinite(from) || !Number.isFinite(to) || to <= from || to - from > 70 * 24 * 3_600_000) throw new MockError('invalidInput', 400);
    if (typeof query['token'] === 'string') {
      const booking = this.bookingByToken(query['token']);
      const profile = this.profile(booking.slug);
      const rules = this.rules(profile);
      const rebook = query['purpose'] === 'rebook';
      const minutes = booking.totalMinutes;
      return { slots: freeSlots(from, to, minutes, rules, this.busy(booking.slug, undefined, now), now, rebook ? {} : { bookingId: booking.id }), durationMinutes: minutes };
    }
    const slug = String(query['slug']);
    const profile = this.profile(slug);
    const addOns = typeof query['addOns'] === 'string' && query['addOns'] !== '' ? query['addOns'].split(',') : Array.isArray(query['addOns']) ? (query['addOns'] as string[]) : [];
    const minutes = this.duration(profile, String(query['serviceId']), addOns, Number(query['guests'] ?? 0));
    return { slots: freeSlots(from, to, minutes, this.rules(profile), this.busy(slug, undefined, now), now), durationMinutes: minutes };
  }

  holdSlot(body: Record<string, unknown>, now = Date.now()): { holdId: string; expiresAt: string } {
    this.maybeFail('holdSlot');
    const slug = String(body['slug']);
    const profile = this.profile(slug);
    const minutes = this.duration(profile, String(body['serviceId']), (body['addOnIds'] as string[] | undefined) ?? [], Number(body['guests'] ?? 0));
    const start = Date.parse(String(body['startsAt']));
    const sessionKey = String(body['sessionKey']);
    if (!Number.isFinite(start) || !isFree(start, minutes, this.rules(profile), this.busy(slug, undefined, now), now, { sessionKey })) throw new MockError('slotTaken', 409);
    for (const hold of [...this.holds.values()]) if (hold.sessionKey === sessionKey) this.holds.delete(hold.id);
    const hold: Hold = { id: `h_${token()}`, slug, startsAt: start, endsAt: start + minutes * MINUTE, sessionKey, expiresAt: now + 5 * MINUTE };
    this.holds.set(hold.id, hold);
    return { holdId: hold.id, expiresAt: new Date(hold.expiresAt).toISOString() };
  }

  sendCode(kind: 'sms' | 'email', body: Record<string, unknown>): { resendAfterSeconds: number } {
    this.maybeFail(kind === 'sms' ? 'sendSmsCode' : 'sendEmailCode');
    this.attempts.set(`${kind}:${String(body[kind === 'sms' ? 'phone' : 'email'])}`, 0);
    return { resendAfterSeconds: this.resendAfterSeconds };
  }

  verifyCode(kind: 'sms' | 'email', body: Record<string, unknown>): { token: string } {
    const target = String(body[kind === 'sms' ? 'phone' : 'email']);
    const key = `${kind}:${target}`;
    const tries = (this.attempts.get(key) ?? 0) + 1;
    this.attempts.set(key, tries);
    if (tries > 5) throw new MockError('tooManyAttempts', 429);
    const expected = kind === 'sms' ? SMS_CODE : EMAIL_CODE;
    if (String(body['code']) !== expected) throw new MockError('codeInvalid', 400);
    return { token: `${kind}:${target}` };
  }

  private proofTarget(proof: VerificationProof): { kind: 'sms' | 'email'; target: string } {
    const value = proof.kind === 'sms' ? proof.idToken : proof.token;
    const [kind, ...rest] = value.split(':');
    if ((kind !== 'sms' && kind !== 'email') || rest.length === 0 || kind !== proof.kind) throw new MockError('codeInvalid', 400);
    return { kind, target: rest.join(':') };
  }

  createBooking(request: CreateBookingRequest, now = Date.now()): BookingResult {
    this.maybeFail('createBooking');
    const previous = this.idempotent.get(request.idempotencyKey);
    if (previous !== undefined) return previous;
    const scenario = this.scenario(request.slug);
    const profile = this.profile(request.slug);
    const proof = this.proofTarget(request.verification);
    if (proof.kind === 'sms' && proof.target !== request.client.phone) throw new MockError('codeInvalid', 400);
    if (proof.kind === 'email' && proof.target !== request.client.email) throw new MockError('codeInvalid', 400);

    let result: BookingResult;
    const phone = request.client.phone;
    const noShow = scenario.noShow[phone];
    if (!profile.booking.accepting) {
      result = { status: 'paused', scope: 'page', ...(profile.booking.pausedUntil === undefined ? {} : { pausedUntil: profile.booking.pausedUntil }) };
    } else if (noShow === 'pauseOnline') {
      result = { status: 'paused', scope: 'client' };
    } else {
      const minutes = this.duration(profile, request.serviceId, request.addOnIds, request.guests.length);
      const start = Date.parse(request.startsAt);
      const ignoreSession = request.holdId === undefined ? undefined : this.holds.get(request.holdId)?.sessionKey;
      if (!isFree(start, minutes, this.rules(profile), this.busy(request.slug, undefined, now), now, ignoreSession === undefined ? {} : { sessionKey: ignoreSession })) {
        const next = freeSlots(start, start + 5 * 24 * 3_600_000, minutes, this.rules(profile), this.busy(request.slug, undefined, now), now).slice(0, 4);
        result = { status: 'slotTaken', nextSlots: next };
      } else {
        const isKnown = scenario.knownClients.includes(phone) || [...this.bookings.values()].some((b) => b.slug === request.slug && b.client.phone === phone);
        const needsApproval = (profile.booking.confirmNewClients && !isKnown) || noShow === 'approveNewBookings';
        const stored: StoredBooking = {
          id: `bk_${token()}`,
          slug: request.slug,
          status: needsApproval ? 'pendingApproval' : 'confirmed',
          serviceId: request.serviceId,
          addOnIds: [...request.addOnIds],
          guestNames: request.guests.map((g) => g.name),
          startsAt: start,
          endsAt: start + minutes * MINUTE,
          totalMinutes: minutes,
          client: { ...request.client },
          policy: profile.policy,
          rescheduleCount: 0,
          intake: scenario.intakeCompleted === true ? 'done' : 'pending',
          checkIn: 'none',
          idempotencyKey: request.idempotencyKey,
        };
        this.bookings.set(stored.id, stored);
        if (request.holdId !== undefined) this.holds.delete(request.holdId);
        const manageToken = token();
        this.manageTokens.set(manageToken, stored.id);
        result = needsApproval
          ? { status: 'pendingApproval', reason: noShow === 'approveNewBookings' ? 'noShowLimit' : 'newClient', manageToken }
          : { status: 'confirmed', manageToken, booking: this.view(stored, now) };
      }
    }
    if (result.status !== 'slotTaken') this.idempotent.set(request.idempotencyKey, result);
    return result;
  }

  joinWaitlist(body: Record<string, unknown>): void {
    this.maybeFail('joinWaitlist');
    this.profile(String(body['slug']));
    this.waitlist.push(body);
  }

  findBookings(body: Record<string, unknown>, now = Date.now()): { bookings: unknown[] } {
    this.maybeFail('findBookings');
    const slug = String(body['slug']);
    const proof = body['verification'] as VerificationProof;
    const { target } = this.proofTarget(proof);
    const profile = this.profile(slug);
    const mine = [...this.bookings.values()].filter((b) => b.slug === slug && b.endsAt > now && (b.status === 'confirmed' || b.status === 'pendingApproval') && (proof.kind === 'sms' ? b.client.phone === target : b.client.email === target));
    return {
      bookings: mine
        .sort((a, b) => a.startsAt - b.startsAt)
        .map((b) => {
          const manageToken = token();
          this.manageTokens.set(manageToken, b.id);
          const view = this.view(b, now);
          return { manageToken, serviceName: view.service.name, startsAt: view.startsAt, endsAt: view.endsAt, totalMinutes: view.totalMinutes, professionalName: profile.displayName };
        }),
    };
  }

  getBooking(value: string, now = Date.now()): BookingView {
    this.maybeFail('getBooking');
    return this.view(this.bookingByToken(value), now);
  }

  confirmPresence(value: string, now = Date.now()): void {
    this.maybeFail('confirmPresence');
    this.bookingByToken(value).clientConfirmedAt = new Date(now).toISOString();
  }

  reportLate(value: string, minutes: number): { lateByMinutes: number; proReply?: string } {
    this.maybeFail('reportLate');
    const booking = this.bookingByToken(value);
    booking.lateByMinutes = minutes;
    if (minutes >= 20) booking.proReply = 'I will wait for you.';
    return { lateByMinutes: minutes, ...(booking.proReply === undefined ? {} : { proReply: booking.proReply }) };
  }

  rescheduleBooking(body: Record<string, unknown>, now = Date.now()): BookingView {
    this.maybeFail('rescheduleBooking');
    const booking = this.bookingByToken(String(body['token']));
    if (rescheduleMode(booking.startsAt, booking.policy, now, booking.rescheduleCount) !== 'direct') throw new MockError('notAllowed', 403);
    const profile = this.profile(booking.slug);
    const start = Date.parse(String(body['startsAt']));
    if (!isFree(start, booking.totalMinutes, this.rules(profile), this.busy(booking.slug, undefined, now), now, { bookingId: booking.id })) throw new MockError('slotTaken', 409);
    booking.movedFrom = new Date(booking.startsAt).toISOString();
    booking.startsAt = start;
    booking.endsAt = start + booking.totalMinutes * MINUTE;
    booking.rescheduleCount += 1;
    delete booking.rescheduleRequest;
    return this.view(booking, now);
  }

  requestReschedule(body: Record<string, unknown>, now = Date.now()): BookingView {
    this.maybeFail('requestReschedule');
    const booking = this.bookingByToken(String(body['token']));
    if (rescheduleMode(booking.startsAt, booking.policy, now, booking.rescheduleCount) !== 'request') throw new MockError('notAllowed', 403);
    const profile = this.profile(booking.slug);
    const start = Date.parse(String(body['startsAt']));
    if (!isFree(start, booking.totalMinutes, this.rules(profile), this.busy(booking.slug, undefined, now), now, { bookingId: booking.id })) throw new MockError('slotTaken', 409);
    booking.rescheduleRequest = { requestedStart: new Date(start).toISOString() };
    this.rescheduleRequests.push({ slug: booking.slug, bookingId: booking.id, startsAt: new Date(start).toISOString(), note: body['note'] });
    return this.view(booking, now);
  }

  cancelBooking(body: Record<string, unknown>, now = Date.now()): { booking: BookingView; countedAsLate: boolean } {
    this.maybeFail('cancelBooking');
    const booking = this.bookingByToken(String(body['token']));
    const mode = cancelMode(booking.startsAt, booking.policy, now);
    if (mode === 'message') throw new MockError('notAllowed', 403);
    booking.status = 'cancelledByClient';
    return { booking: this.view(booking, now), countedAsLate: mode === 'allowLate' && booking.policy.lateCancelCounts === true };
  }

  // MARK: Portal

  seedPortal(slug: string, name: string, phone: string, mode: PortalView['rebookMode'] = 'direct'): string {
    this.scenario(slug);
    const value = token();
    this.portalTokens.set(value, { slug, phone, name, mode });
    return value;
  }

  getPortal(value: string, now = Date.now()): PortalView {
    this.maybeFail('getPortal');
    const portal = this.portalTokens.get(value);
    if (portal === undefined) throw new MockError('expired', 410);
    const profile = this.profile(portal.slug);
    const mine = [...this.bookings.values()].filter((b) => b.slug === portal.slug && b.client.phone === portal.phone);
    const upcoming = mine.filter((b) => b.status === 'confirmed' && b.endsAt > now).sort((a, b) => a.startsAt - b.startsAt)[0];
    const past = mine.filter((b) => b.status === 'completed').sort((a, b) => b.startsAt - a.startsAt);
    const recommended = zonedDateKey(now + 28 * 24 * 3_600_000, profile.timeZoneID);
    const service = profile.services[1] ?? profile.services[0];
    if (service === undefined) throw new MockError('notFound', 404);
    const upcomingToken = upcoming === undefined ? undefined : [...this.manageTokens.entries()].find(([, id]) => id === upcoming.id)?.[0];
    return {
      professional: this.lite(profile),
      client: { firstName: portal.name },
      next: { serviceId: service.id, serviceName: service.name, durationMinutes: service.durationMinutes, recommendedDate: recommended },
      past: past.map((b) => ({ date: new Date(b.startsAt).toISOString(), serviceName: profile.services.find((s) => s.id === b.serviceId)?.name ?? '', note: 'Your skin responded well. Keep products gentle and fragrance-free.' })),
      aftercare: past.length === 0 ? [] : [{ date: new Date(past[0]?.startsAt ?? now).toISOString(), serviceName: service.name, lines: ['Use only a gentle, fragrance-free cleanser tonight.', 'Wear sunscreen in the morning.', 'Message Maria if anything feels uncomfortable.'] }],
      products: [{ name: 'Calming serum', note: 'Used in your treatment' }],
      forms: { intake: 'pending', checkIn: 'available' },
      ...(upcoming === undefined || upcomingToken === undefined ? {} : { upcoming: { manageToken: upcomingToken, startsAt: new Date(upcoming.startsAt).toISOString(), serviceName: profile.services.find((s) => s.id === upcoming.serviceId)?.name ?? '' } }),
      rebookMode: portal.mode,
    };
  }

  rebook(body: Record<string, unknown>, now = Date.now()): BookingResult {
    this.maybeFail('rebook');
    const value = String(body['token']);
    const portal = this.portalTokens.get(value);
    let slug: string;
    let client: StoredBooking['client'];
    let serviceId: string;
    let policy: PolicyValues;
    if (portal !== undefined) {
      slug = portal.slug;
      client = { name: portal.name, phone: portal.phone, locale: 'en' };
      serviceId = 'brazilian';
      policy = this.profile(slug).policy;
      if (portal.mode === 'paused') return { status: 'paused', scope: 'client' };
    } else {
      const base = this.bookingByToken(value);
      slug = base.slug;
      client = base.client;
      serviceId = base.serviceId;
      policy = this.profile(slug).policy;
    }
    const profile = this.profile(slug);
    const service = profile.services.find((s) => s.id === serviceId);
    if (service === undefined) throw new MockError('notFound', 404);
    const start = Date.parse(String(body['startsAt']));
    if (!isFree(start, service.durationMinutes, this.rules(profile), this.busy(slug, undefined, now), now)) {
      return { status: 'slotTaken', nextSlots: freeSlots(start, start + 5 * 24 * 3_600_000, service.durationMinutes, this.rules(profile), this.busy(slug, undefined, now), now).slice(0, 4) };
    }
    const approval = portal?.mode === 'approval';
    const stored: StoredBooking = {
      id: `bk_${token()}`,
      slug,
      status: approval ? 'pendingApproval' : 'confirmed',
      serviceId,
      addOnIds: [],
      guestNames: [],
      startsAt: start,
      endsAt: start + service.durationMinutes * MINUTE,
      totalMinutes: service.durationMinutes,
      client,
      policy,
      rescheduleCount: 0,
      intake: 'done',
      checkIn: 'none',
    };
    this.bookings.set(stored.id, stored);
    const manageToken = token();
    this.manageTokens.set(manageToken, stored.id);
    return approval ? { status: 'pendingApproval', reason: 'newClient', manageToken } : { status: 'confirmed', manageToken, booking: this.view(stored, now) };
  }

  // MARK: Sealed forms

  getFormContext(value: string, now = Date.now()): FormContext {
    this.maybeFail('getFormContext');
    if (this.inboxKey === null) throw new Error('mock not initialised');
    const booking = this.bookingByToken(value);
    const profile = this.profile(booking.slug);
    void now;
    return {
      professional: this.lite(profile),
      bookingId: booking.id,
      client: { firstName: booking.client.name.split(/\s+/)[0] ?? booking.client.name },
      inboxKey: this.inboxKey,
      intake: {
        available: booking.status === 'confirmed' || booking.status === 'completed' || booking.status === 'pendingApproval',
        completedWithin12Months: booking.intake === 'done',
        formVersion: '2026-10.1',
        questions: QUESTIONS,
      },
      checkIn: { available: booking.checkIn === 'available' || booking.status === 'completed', serviceName: profile.services.find((s) => s.id === booking.serviceId)?.name ?? '' },
      ...(booking.intake === 'done' ? { lastIntakeAt: new Date(now - 20 * 24 * 3_600_000).toISOString() } : {}),
    };
  }

  async submitSealed(body: Record<string, unknown>): Promise<void> {
    this.maybeFail('submitSealed');
    if (this.inboxKey === null) throw new Error('mock not initialised');
    const booking = this.bookingByToken(String(body['token']));
    const envelope = body['envelope'] as SealedEnvelope | undefined;
    if (envelope === undefined || envelope.v !== 1 || envelope.keyId !== this.inboxKey.keyId || !['intake', 'checkin', 'datarequest'].includes(envelope.kind)) throw new MockError('invalidInput', 400);
    if (typeof envelope.itemId !== 'string' || typeof envelope.enc !== 'string' || typeof envelope.ct !== 'string') throw new MockError('invalidInput', 400);
    // The server never sees the answers. This stand-in opens the envelope only so a test can compare it to what was typed.
    const ctBytes = decodeBase64Url(envelope.ct).length;
    if (ctBytes > PAYLOAD_LIMITS[envelope.kind] + 64) throw new MockError('tooLarge', 413);
    if (this.itemIds.has(envelope.itemId)) return;
    let text: string;
    try {
      text = await openEnvelope(envelope, this.inboxSeed);
    } catch {
      throw new MockError('invalidInput', 400);
    }
    this.itemIds.add(envelope.itemId);
    this.inbox.push({ slug: booking.slug, bookingId: booking.id, kind: envelope.kind, itemId: envelope.itemId, payload: JSON.parse(text) as Record<string, unknown>, sizeBytes: ctBytes });
    if (envelope.kind === 'intake') booking.intake = 'done';
  }

  // MARK: Test controls

  seedBooking(input: { slug: string; startsInMinutes: number; status?: BookingStatus; serviceId?: string; phone?: string; name?: string; rescheduleCount?: number; intake?: 'pending' | 'done'; guests?: number; policy?: Partial<PolicyValues>; checkIn?: boolean }, now = Date.now()): { token: string; bookingId: string; portalToken: string } {
    const profile = this.profile(input.slug);
    const serviceId = input.serviceId ?? 'brazilian';
    const guests = Array.from({ length: input.guests ?? 0 }, () => 'Guest');
    const minutes = this.duration(profile, serviceId, [], guests.length);
    const start = now + input.startsInMinutes * MINUTE;
    const stored: StoredBooking = {
      id: `bk_${token()}`,
      slug: input.slug,
      status: input.status ?? 'confirmed',
      serviceId,
      addOnIds: [],
      guestNames: guests,
      startsAt: start,
      endsAt: start + minutes * MINUTE,
      totalMinutes: minutes,
      client: { name: input.name ?? 'Helena Duarte', phone: input.phone ?? '+5511987654321', locale: 'en' },
      policy: { ...profile.policy, ...input.policy },
      rescheduleCount: input.rescheduleCount ?? 0,
      intake: input.intake ?? 'pending',
      checkIn: input.checkIn === true ? 'available' : 'none',
    };
    this.bookings.set(stored.id, stored);
    const manageToken = token();
    this.manageTokens.set(manageToken, stored.id);
    const portalToken = this.seedPortal(input.slug, (input.name ?? 'Helena Duarte').split(/\s+/)[0] ?? 'Helena', stored.client.phone);
    return { token: manageToken, bookingId: stored.id, portalToken };
  }

  /** What the server holds for a professional's bookings, so a test can compare it with what the page showed. */
  listBookings(slug: string): Record<string, unknown>[] {
    return [...this.bookings.values()]
      .filter((booking) => booking.slug === slug)
      .map((booking) => ({
        id: booking.id,
        status: booking.status,
        serviceId: booking.serviceId,
        addOnIds: booking.addOnIds,
        guestNames: booking.guestNames,
        startsAt: new Date(booking.startsAt).toISOString(),
        totalMinutes: booking.totalMinutes,
        client: booking.client,
        rescheduleCount: booking.rescheduleCount,
        clientConfirmedAt: booking.clientConfirmedAt ?? null,
        lateByMinutes: booking.lateByMinutes ?? null,
        intake: booking.intake,
      }));
  }

  seedExpired(slug: string): string {
    this.scenario(slug);
    const value = token();
    this.expiredTokens.set(value, slug);
    return value;
  }

  async keyId(): Promise<string> {
    const { publicKey } = await inboxKeyFromSeed(this.inboxSeed);
    return keyIdOf(decodeBase64Url(publicKey.pub));
  }

  freeUntilFor(bookingId: string): string | null {
    const booking = this.bookings.get(bookingId);
    return booking === undefined ? null : new Date(freeUntil(booking.startsAt, booking.policy)).toISOString();
  }

  dayKey(slug: string, instant: number): string {
    return zonedDateKey(instant, this.profile(slug).timeZoneID);
  }

  instantAt(slug: string, day: string, hour: number, minute: number): number {
    return instantFromZoned(day, hour, minute, this.profile(slug).timeZoneID);
  }
}
