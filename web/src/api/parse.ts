// Shallow checks on what the server returns. The server is ours, so each parser verifies the fields the page
// cannot render without and trusts the rest of the shape; a response that fails becomes a friendly error page
// instead of an exception in a component.

import { ApiError } from './errors';
import type {
  BookingResult,
  BookingView,
  FormContext,
  FoundBooking,
  HoldResponse,
  PortalView,
  PublicProfile,
  SendCodeResponse,
  SlotsResponse,
} from './types';

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

export function parsePublicProfile(raw: unknown): PublicProfile {
  const value = record(raw);
  text(value['slug']);
  text(value['displayName']);
  text(value['timeZoneID']);
  text(value['currencyCode']);
  list(value['services']);
  list(value['addOns']);
  list(list(record(value['credentials'])['items']));
  const booking = record(value['booking']);
  whole(booking['maxDaysAhead']);
  const key = record(value['inboxKey']);
  text(key['keyId']);
  text(key['pub']);
  record(value['policy']);
  record(value['channels']);
  return value as unknown as PublicProfile;
}

export function parseSlots(raw: unknown): SlotsResponse {
  const value = record(raw);
  const slots = list(value['slots']).map(text);
  return { slots, durationMinutes: whole(value['durationMinutes']) };
}

export function parseHold(raw: unknown): HoldResponse {
  const value = record(raw);
  return { holdId: text(value['holdId']), expiresAt: text(value['expiresAt']) };
}

export function parseSendCode(raw: unknown): SendCodeResponse {
  return { resendAfterSeconds: whole(record(raw)['resendAfterSeconds']) };
}

export function parseToken(raw: unknown): string {
  return text(record(raw)['token']);
}

export function parseBookingView(raw: unknown): BookingView {
  const value = record(raw);
  text(value['id']);
  text(value['status']);
  text(value['startsAt']);
  text(value['endsAt']);
  whole(value['totalMinutes']);
  record(value['service']);
  record(value['professional']);
  record(value['policy']);
  record(value['forms']);
  return value as unknown as BookingView;
}

export function parseBookingResult(raw: unknown): BookingResult {
  const value = record(raw);
  switch (text(value['status'])) {
    case 'confirmed':
      text(value['manageToken']);
      parseBookingView(value['booking']);
      return value as unknown as BookingResult;
    case 'pendingApproval':
    case 'paused':
      return value as unknown as BookingResult;
    case 'slotTaken':
      list(value['nextSlots']);
      return value as unknown as BookingResult;
    default:
      return bad();
  }
}

export function parseFound(raw: unknown): FoundBooking[] {
  return list(record(raw)['bookings']).map((item) => {
    const value = record(item);
    text(value['manageToken']);
    text(value['startsAt']);
    return value as unknown as FoundBooking;
  });
}

export function parsePortal(raw: unknown): PortalView {
  const value = record(raw);
  record(value['professional']);
  record(value['client']);
  list(value['past']);
  list(value['aftercare']);
  list(value['products']);
  record(value['forms']);
  return value as unknown as PortalView;
}

export function parseFormContext(raw: unknown): FormContext {
  const value = record(raw);
  record(value['professional']);
  text(value['bookingId']);
  const key = record(value['inboxKey']);
  text(key['keyId']);
  text(key['pub']);
  const intake = record(value['intake']);
  list(intake['questions']);
  record(value['checkIn']);
  return value as unknown as FormContext;
}
