// Creating the booking (D32): one call, the server decides. The answer is one of four, and each has its screen:
// confirmed -> Bk-8, pendingApproval -> Bk-10 (she confirms it herself), paused -> Bk-10 (for her) or Bk-1 (for
// everyone), slotTaken -> back to the times with the next free ones. The page never learns why a booking needs
// approval beyond "she will confirm this one", and never whether a phone number is already a client.

import { api } from '../../api/client';
import type { BookingResult, CreateBookingRequest, FirstVisitAnswers, PublicProfile } from '../../api/types';
import { forgetPublicPage } from '../../app/pageData';
import { navigate, slugRoute } from '../../app/router';
import type { BookingEvent, BookingState } from '../../app/booking/machine';
import type { LocaleId } from '../../lib/locales';
import { normalizePhone, phoneRegion } from '../../lib/phone';

function hasAnswers(answers: FirstVisitAnswers): boolean {
  return answers.heardFrom !== null || answers.hadBefore !== null || answers.note.trim() !== '';
}

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
  return {
    slug: profile.slug,
    serviceId: draft.serviceId,
    addOnIds: draft.addOnIds,
    guests: draft.guestNames.map((name) => ({ name })),
    startsAt: draft.startsAt,
    ...(draft.holdId === null ? {} : { holdId: draft.holdId }),
    client: { name: draft.name.trim(), phone: phone.e164, ...(email === '' ? {} : { email }), locale },
    ...(hasAnswers(answers) ? { firstVisit: { ...answers, note: answers.note.trim() } } : {}),
    verification: proof,
    idempotencyKey: draft.idempotencyKey,
  };
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
  const result: BookingResult = await api.createBooking(request);
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
        forgetPublicPage(profile.slug);
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

