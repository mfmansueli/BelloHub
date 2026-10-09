// Creating the booking (D32, API.md 5.8): one call, the server decides. The answer is one of four, and each has its
// screen: confirmed -> Bk-8, pendingApproval -> Bk-10 (she confirms it herself), paused -> Bk-10 (for her) or Bk-1
// (for everyone), slotTaken -> back to the times with the next free ones. The page never learns why a booking needs
// approval beyond "she will confirm this one", and never whether a phone number is already a client.
//
// The server says "paused" without saying for whom (deliberate: a pause for one client is not announced). The page
// reads her public page again: if it no longer accepts bookings the pause is for everyone, otherwise it is about her.

import { api } from '../../api/client';
import type { BookingResult, CreateBookingRequest, FirstVisitAnswers, PublicProfile } from '../../api/types';
import { forgetPublicPage, loadPublicPage } from '../../app/pageData';
import { navigate, slugRoute } from '../../app/router';
import type { BookingEvent, BookingState } from '../../app/booking/machine';
import type { LocaleId } from '../../lib/locales';
import { normalizePhone, phoneRegion } from '../../lib/phone';

/** The server keeps `note` only (<= 300 chars). */
export const NOTE_MAX_LENGTH = 300;

/** The request for what she chose, or null when something required is missing (the screens prevent it). */
export function buildCreateRequest(
  profile: PublicProfile,
  state: BookingState,
  locale: LocaleId,
  answers: FirstVisitAnswers,
): CreateBookingRequest | null {
  const { draft, proof } = state;
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
  const request = buildCreateRequest(profile, state, locale, answers);
  if (request === null) {
    navigate(slugRoute(profile.slug, 'you'), true);
    return;
  }
  const outcome = await api.createBooking(request);
  const result: BookingResult = outcome.status === 'paused' ? { ...outcome, scope: await pauseScope(profile.slug) } : outcome;
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
