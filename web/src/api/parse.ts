// From the wire (API.md) to what the screens render. Each parser verifies the fields the page cannot render
// without and trusts the rest of the shape (the server is ours); a response that fails becomes a friendly error
// page instead of an exception in a component. The derived fields (first name, rules as lines, the professional's
// full profile beside a booking) are computed here once so no screen repeats them.

import { ApiError } from './errors';
import type {
  BookedResult,
  BookingOutcome,
  BookingView,
  FormContext,
  FormQuestion,
  FoundBooking,
  HoldResponse,
  LateResponse,
  MovedResponse,
  OfferedHold,
  PortalView,
  ProfessionalLite,
  PublicProfile,
  QuestionKind,
  RulesByLocale,
  SendCodeResponse,
  SlotsResponse,
  WireBooking,
  WireFormContext,
  WireHoldResponse,
  WirePortal,
  WireProfile,
  WireSlotsResponse,
} from './types';
import { DEFAULT_LOCALE, isLocaleId, type LocaleId } from '../lib/locales';

function bad(): never {
  throw new ApiError('server');
}

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return bad();
  return value as Record<string, unknown>;
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : bad();
}

function list(value: unknown): unknown[] {
  return Array.isArray(value) ? (value as unknown[]) : bad();
}

function whole(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : bad();
}

/** The page talks about her by first name: the first word of what she published. */
export function firstNameOf(displayName: string): string {
  return displayName.trim().split(/\s+/)[0] ?? displayName;
}

/** Her app publishes one text per language; the page shows it as lines (blank lines are separators). */
export function rulesFromText(rulesText: unknown): RulesByLocale {
  if (typeof rulesText !== 'object' || rulesText === null) return {};
  const out: Record<string, { text: string }[]> = {};
  for (const [locale, value] of Object.entries(rulesText as Record<string, unknown>)) {
    if (typeof value !== 'string') continue;
    const lines = value
      .split(/\r?\n/)
      .map((line) => line.replace(/^\s*[-•*]\s+/, '').trim())
      .filter((line) => line !== '')
      .map((line) => ({ text: line }));
    if (lines.length > 0) out[locale] = lines;
  }
  return out;
}

export function professionalLite(profile: WireProfile): ProfessionalLite {
  const offered = profile.locales.filter(isLocaleId);
  const locales: readonly LocaleId[] = offered.length > 0 ? offered : [DEFAULT_LOCALE];
  return {
    slug: profile.slug,
    displayName: profile.displayName,
    firstName: firstNameOf(profile.displayName),
    ...(profile.businessName === undefined ? {} : { businessName: profile.businessName }),
    ...(profile.photo === undefined ? {} : { photo: profile.photo }),
    ...(profile.whatsappE164 === undefined ? {} : { whatsappE164: profile.whatsappE164 }),
    locales,
    defaultLocale: locales[0] ?? DEFAULT_LOCALE,
    regionCode: profile.regionCode,
    timeZoneID: profile.timeZoneID,
    currencyCode: profile.currencyCode,
    ...(profile.city === undefined ? {} : { city: profile.city }),
  };
}

export function parsePublicPage(raw: unknown): PublicProfile {
  const value = record(raw);
  const profile = record(value['profile']);
  text(profile['slug']);
  text(profile['displayName']);
  text(profile['timeZoneID']);
  text(profile['currencyCode']);
  text(profile['regionCode']);
  list(profile['locales']);
  list(profile['services']);
  list(profile['addOns']);
  list(profile['credentials']);
  const booking = record(profile['booking']);
  whole(booking['maxDaysAhead']);
  const key = record(profile['inboxKey']);
  text(key['keyId']);
  text(key['pub']);
  record(profile['policy']);
  const features = record(value['features']);
  const wire = profile as unknown as WireProfile;
  const { bio, legalNotice } = wire;
  return {
    ...professionalLite(wire),
    ...(bio === undefined ? {} : { bio }),
    credentials: wire.credentials,
    services: wire.services,
    addOns: wire.addOns,
    rules: rulesFromText(wire.rulesText),
    policy: wire.policy,
    booking: wire.booking,
    ...(legalNotice === undefined ? {} : { legalNotice }),
    inboxKey: wire.inboxKey,
    intakeAvailable: value['intakeAvailable'] === true,
    features: {
      whatsAppAutomation: features['whatsAppAutomation'] === true,
      smsCallingCodes: Array.isArray(features['smsCallingCodes']) ? (features['smsCallingCodes'] as unknown[]).filter((code): code is string => typeof code === 'string') : [],
    },
    serverTime: text(value['serverTime']),
  };
}

export function parseSlots(raw: unknown): SlotsResponse {
  const value = record(raw) as unknown as WireSlotsResponse;
  const days = list(value.days);
  const slots = days.flatMap((day) => list(record(day)['slots']).map(text)).sort();
  // `more` is absent when nothing is hidden (and from a server older than D56).
  const more = days
    .flatMap((day) => {
      const extra = record(day)['more'];
      return extra === undefined ? [] : list(extra).map(text);
    })
    .sort();
  return { slots, more, durationMinutes: whole(value.durationMinutes), timeZoneID: text(value.timeZoneID), paused: value.paused };
}

/** A hold that was not granted is an error for the page: it already knows how to show "that time was just taken". */
export function parseHold(raw: unknown): HoldResponse {
  const value = record(raw) as unknown as WireHoldResponse;
  switch (value.status) {
    case 'held':
      return { holdId: text(value.holdId), expiresAt: text(value.expiresAt) };
    case 'slotTaken':
      throw new ApiError('slotTaken', 200);
    case 'paused':
      throw new ApiError('paused', 200);
    default:
      return bad();
  }
}

export function parseOfferedHold(raw: unknown): OfferedHold {
  const value = record(raw);
  const guests = whole(value['guests']);
  return {
    serviceId: text(value['serviceId']),
    addOnIds: list(value['addOnIds']).map(text),
    guests: Math.min(guests, 2),
    startsAt: text(value['startsAt']),
    endsAt: text(value['endsAt']),
    expiresAt: text(value['expiresAt']),
  };
}

export function parseSendCode(raw: unknown): SendCodeResponse {
  const value = record(raw);
  return { resendAfterSeconds: whole(value['resendAfterSeconds']), ...(typeof value['expiresInSeconds'] === 'number' ? { expiresInSeconds: value['expiresInSeconds'] } : {}) };
}

export function parseProof(raw: unknown): string {
  return text(record(raw)['proof']);
}

export function parseBookingOutcome(raw: unknown): BookingOutcome {
  const value = record(raw);
  switch (text(value['status'])) {
    case 'confirmed':
    case 'pendingApproval': {
      text(value['manageToken']);
      text(value['bookingId']);
      text(value['startsAt']);
      text(value['endsAt']);
      text(value['serviceName']);
      return value as unknown as BookedResult;
    }
    case 'slotTaken':
      return { status: 'slotTaken', alternatives: list(value['alternatives']).map(text) };
    case 'paused':
      return { status: 'paused', ...(typeof value['pausedUntil'] === 'string' ? { pausedUntil: value['pausedUntil'] } : {}) };
    default:
      return bad();
  }
}

export function parseFound(raw: unknown): FoundBooking[] {
  return list(record(raw)['bookings']).map((item) => {
    const value = record(item);
    text(value['manageToken']);
    text(value['startsAt']);
    text(value['endsAt']);
    text(value['serviceName']);
    return value as unknown as FoundBooking;
  });
}

export function parseWireBooking(raw: unknown): WireBooking {
  const value = record(raw);
  text(value['bookingId']);
  text(value['status']);
  text(value['phase']);
  text(value['slug']);
  text(value['startsAt']);
  text(value['endsAt']);
  text(value['serverTime']);
  whole(value['durationMinutes']);
  whole(value['rescheduleCount']);
  record(value['service']);
  list(value['addOns']);
  record(value['professional']);
  record(value['policy']);
  record(value['actions']);
  text(record(value['client'])['name']);
  return value as unknown as WireBooking;
}

/** The booking with the professional's public profile beside it (one `getPublicPage` per token page). */
export function bookingView(wire: WireBooking, professional: ProfessionalLite): BookingView {
  const { professional: header, rulesText, client, ...rest } = wire;
  const businessName = header.businessName ?? professional.businessName;
  return {
    ...rest,
    professional: { ...professional, ...(businessName === undefined ? {} : { businessName }) },
    client: { name: client.name, firstName: firstNameOf(client.name) },
    rules: rulesFromText(rulesText),
  };
}

export function parseConfirmed(raw: unknown): string {
  return text(record(raw)['clientConfirmedAt']);
}

export function parseLate(raw: unknown): LateResponse {
  const value = record(raw);
  return { lateByMinutes: whole(value['lateByMinutes']), reportedAt: text(value['reportedAt']) };
}

export function parseCancelled(raw: unknown): { isLateCancellation: boolean } {
  const value = record(raw);
  if (value['status'] !== 'cancelled') bad();
  return { isLateCancellation: value['isLateCancellation'] === true };
}

/** `slotTaken` becomes the error the reschedule screen already handles (it reloads the times). */
export function parseMoved(raw: unknown): MovedResponse {
  const value = record(raw);
  switch (text(value['status'])) {
    case 'moved':
      return { status: 'moved', startsAt: text(value['startsAt']), endsAt: text(value['endsAt']), rescheduleCount: whole(value['rescheduleCount']) };
    case 'slotTaken':
      throw new ApiError('slotTaken', 200);
    default:
      return bad();
  }
}

export function parseRequested(raw: unknown): void {
  const value = record(raw);
  switch (text(value['status'])) {
    case 'requested':
      return;
    case 'slotTaken':
      throw new ApiError('slotTaken', 200);
    default:
      return bad();
  }
}

export function parseWirePortal(raw: unknown): WirePortal {
  const value = record(raw);
  text(value['slug']);
  text(value['clientName']);
  record(value['professional']);
  list(value['upcoming']);
  list(value['past']);
  list(value['aftercare']);
  list(value['products']);
  return value as unknown as WirePortal;
}

export function portalView(wire: WirePortal, professional: ProfessionalLite): PortalView {
  const { professional: header, ...rest } = wire;
  return { ...rest, professional: { ...professional, displayName: header.displayName || professional.displayName }, clientFirstName: firstNameOf(wire.clientName) };
}

export function parseWireFormContext(raw: unknown): WireFormContext {
  const value = record(raw);
  text(value['bookingId']);
  const key = record(value['inboxKey']);
  text(key['keyId']);
  text(key['pub']);
  record(value['template']);
  return value as unknown as WireFormContext;
}

const QUESTION_KINDS: readonly QuestionKind[] = ['yesNo', 'choice', 'multiChoice', 'text'];

function localized(value: unknown): Record<string, string> | undefined {
  if (typeof value === 'string') return { [DEFAULT_LOCALE]: value };
  if (typeof value !== 'object' || value === null) return undefined;
  const out: Record<string, string> = {};
  for (const [locale, label] of Object.entries(value as Record<string, unknown>)) if (typeof label === 'string') out[locale] = label;
  return Object.keys(out).length === 0 ? undefined : out;
}

/**
 * The questions inside the opaque template (`template.questions`, or the template itself as a list). A question
 * names its kind as `kind` or `type`; one the page cannot show is left out rather than breaking the form.
 */
export function questionsOf(template: unknown): FormQuestion[] {
  const source = Array.isArray(template) ? template : (record(template)['questions'] ?? []);
  if (!Array.isArray(source)) return [];
  const out: FormQuestion[] = [];
  for (const item of source) {
    if (typeof item !== 'object' || item === null) continue;
    const value = item as Record<string, unknown>;
    const kind = typeof value['kind'] === 'string' ? value['kind'] : value['type'];
    const label = localized(value['label']);
    if (typeof value['key'] !== 'string' || typeof kind !== 'string' || !(QUESTION_KINDS as readonly string[]).includes(kind) || label === undefined) continue;
    const hint = localized(value['hint']);
    const options = Array.isArray(value['options'])
      ? (value['options'] as unknown[]).flatMap((option) => {
          if (typeof option !== 'object' || option === null) return [];
          const entry = option as Record<string, unknown>;
          const optionLabel = localized(entry['label']);
          return typeof entry['value'] === 'string' && optionLabel !== undefined ? [{ value: entry['value'], label: optionLabel }] : [];
        })
      : undefined;
    out.push({
      key: value['key'],
      kind: kind as QuestionKind,
      label,
      ...(hint === undefined ? {} : { hint }),
      ...(value['required'] === true ? { required: true } : {}),
      ...(options === undefined ? {} : { options }),
      ...(value['audience'] === 'adult' || value['audience'] === 'minor' ? { audience: value['audience'] } : {}),
    });
  }
  return out;
}

/** Everything the sealed pages need: the booking (who, which visit), her profile (the key is on both), the form. */
export function formContext(booking: BookingView, form: WireFormContext | null, inboxKey: FormContext['inboxKey']): FormContext {
  return {
    professional: booking.professional,
    bookingId: booking.bookingId,
    client: { firstName: booking.client.firstName },
    inboxKey: form?.inboxKey ?? inboxKey,
    intake: {
      available: form !== null,
      completedWithin12Months: form?.intakeCompletedWithinMonths === true,
      formVersion: form === null ? '' : String(form.formVersion),
      questions: form === null ? [] : questionsOf(form.template),
    },
    // The skin check-in (Cl-5) is for after the visit.
    checkIn: { available: booking.phase === 'past' && booking.status === 'confirmed', serviceName: booking.service.name },
  };
}
