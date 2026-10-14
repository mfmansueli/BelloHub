import type { PublicProfile } from '../../api/types';

export type RebookOfferState = 'ready' | 'guests' | 'offer';
type CurrentOffer = Pick<PublicProfile, 'services' | 'addOns'> &
  { readonly booking: Pick<PublicProfile['booking'], 'maxGuests'> };

/** Duration of the current offer, or nil when its service/add-ons are no longer published. */
export function currentRebookMinutes(
  profile: CurrentOffer, serviceId: string, addOnIds: readonly string[], guests: number,
): number | null {
  const service = profile.services.find((item) => item.id === serviceId);
  if (service === undefined || new Set(addOnIds).size !== addOnIds.length) return null;
  const addOns = addOnIds.map((id) => profile.addOns.find((item) => item.id === id));
  if (addOns.some((item) => item === undefined)) return null;
  return service.durationMinutes * (guests + 1) +
    addOns.reduce((sum, item) => sum + (item?.minutes ?? 0), 0);
}

/** The exact previous offer must still be bookable; never silently drop guests or add-ons. */
export function rebookOfferState(
  profile: CurrentOffer,
  serviceId: string, addOnIds: readonly string[], guests: number,
): RebookOfferState {
  if (!Number.isInteger(guests) || guests < 0 || guests > profile.booking.maxGuests) return 'guests';
  const minutes = currentRebookMinutes(profile, serviceId, addOnIds, guests);
  return minutes !== null && minutes <= 12 * 60 ? 'ready' : 'offer';
}
