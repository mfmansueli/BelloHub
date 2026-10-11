// Creating the booking (D32, API.md 5.8): one call, the server decides. The answer is one of four, and each has its
// screen: confirmed -> Bk-8, pendingApproval -> Bk-10 (she confirms it herself), paused -> Bk-10 (for her) or Bk-1
// (for everyone), slotTaken -> back to the times with the next free ones. The page never learns why a booking needs
// approval beyond "she will confirm this one", and never whether a phone number is already a client.
//
// The server says "paused" without saying for whom (deliberate: a pause for one client is not announced). The page
// reads her public page again: if it no longer accepts bookings the pause is for everyone, otherwise it is about her.
//
// Two ways past the e-mail code (API.md 5.8): a trusted device (a returning client; when the server will not take it
// this time the page goes back to the code), and "Confirm on WhatsApp" when the code never arrived (always a request,
// unverified; Bk-10 then prefills her WhatsApp message with the reference).

import { api } from '../../api/client';
import { ApiError } from '../../api/errors';
import type { BookingOutcome, BookingProof, BookingResult, CreateBookingRequest, FirstVisitAnswers, PublicProfile } from '../../api/types';
import { forgetPublicPage, loadPublicPage } from '../../app/pageData';
import { navigate, slugRoute } from '../../app/router';
import type { BookingEvent, BookingState } from '../../app/booking/machine';
import type { LocaleId } from '../../lib/locales';
import { normalizePhone, phoneRegion } from '../../lib/phone';
import { forgetDeviceLocally, rememberDevice } from '../../lib/trustedDevice';
import { EMPTY_FIRST_VISIT } from '../../app/booking/machine';

/** The server keeps `note` only (<= 300 chars). */
export const NOTE_MAX_LENGTH = 300;

/** The request for what she chose, or null when something required is missing (the screens prevent it). */
export function buildCreateRequest(
  profile: PublicProfile,
  state: BookingState,
  locale: LocaleId,
  answers: FirstVisitAnswers,
  proof: BookingProof | null = state.proof,
): CreateBookingRequest | null {
  const { draft } = state;
  if (draft.serviceId === null || draft.startsAt === null || proof === null) return null;
  const phone = normalizePhone(draft.phoneInput, phoneRegion(draft.phoneCountry));
  if (!phone.ok) return null;
  const email = draft.email.trim();
  const note = answers.note.trim().slice(0, NOTE_MAX_LENGTH);
  return {
    slug: profile.slug,
    serviceId: draft.serviceId,
    addOnIds: draft.addOnIds,
    // Guests are a count: the server stores no guest names (API.md 5.8). The page never asks for names (D48).
    guests: draft.guests,
    startsAt: draft.startsAt,
    client: { name: draft.name.trim(), phone: phone.e164, ...(email === '' ? {} : { email }), locale },
    ...(note === '' ? {} : { note }),
    verification: proof,
    idempotencyKey: draft.idempotencyKey,
    holdKey: draft.holdKey,
  };
}

/** Whether a pause is for everyone (her page says so) or only about this client. */
export async function pauseScope(slug: string): Promise<'page' | 'client'> {
  forgetPublicPage(slug);
  try {
    const fresh = await loadPublicPage(slug);
    return fresh.booking.acceptingBookings ? 'client' : 'page';
  } catch {
    return 'client';
  }
}

/** Sends the booking and moves to the screen the answer names. Throws only for errors the screen should show. */
export async function submitBooking(
  profile: PublicProfile,
  state: BookingState,
  locale: LocaleId,
  answers: FirstVisitAnswers,
  dispatch: (event: BookingEvent) => void,
): Promise<void> {
  await send(profile, buildCreateRequest(profile, state, locale, answers), dispatch);
}

/**
 * "I didn't get the code" -> "Confirm with <her> on WhatsApp": the booking is made without a proof and waits for her.
 * Only what the page already collected travels (no first-visit note: she has not reached that screen).
 */
export async function submitUnverified(
  profile: PublicProfile,
  state: BookingState,
  locale: LocaleId,
  dispatch: (event: BookingEvent) => void,
): Promise<void> {
  await send(profile, buildCreateRequest(profile, state, locale, EMPTY_FIRST_VISIT, { method: 'whatsapp' }), dispatch);
}

async function send(
  profile: PublicProfile,
  request: CreateBookingRequest | null,
  dispatch: (event: BookingEvent) => void,
): Promise<void> {
  if (request === null) {
    navigate(slugRoute(profile.slug, 'you'), true);
    return;
  }
  let outcome: BookingOutcome;
  try {
    outcome = await api.createBooking(request);
  } catch (error) {
    if (request.verification.method === 'device' && error instanceof ApiError && (error.code === 'verificationRequired' || error.code === 'codeExpired')) {
      // A token the server no longer knows (forgotten, expired) is dropped; one it knows stays for next time. Either
      // way this booking goes through the code.
      if (error.code === 'codeExpired') forgetDeviceLocally(profile.slug);
      dispatch({ type: 'needsCode' });
      navigate(slugRoute(profile.slug, 'verify'), true);
      return;
    }
    throw error;
  }
  const result: BookingResult = outcome.status === 'paused' ? { ...outcome, scope: await pauseScope(profile.slug) } : outcome;
  if (result.status === 'confirmed' && result.deviceToken !== undefined && result.deviceTokenExpiresAt !== undefined && request.client.email !== undefined) {
    rememberDevice(profile.slug, request.client.email, result.deviceToken, result.deviceTokenExpiresAt);
  }
  dispatch({ type: 'result', result });
  switch (result.status) {
    case 'confirmed':
      navigate(slugRoute(profile.slug, 'booked'));
      break;
    case 'pendingApproval':
      navigate(slugRoute(profile.slug, 'review'));
      break;
    case 'paused':
      if (result.scope === 'page') {
        // Paused for everyone: her page reloads with the notice.
        navigate(slugRoute(profile.slug), true);
      } else {
        navigate(slugRoute(profile.slug, 'review'));
      }
      break;
    case 'slotTaken':
      navigate(slugRoute(profile.slug, 'time'));
      break;
  }
}
