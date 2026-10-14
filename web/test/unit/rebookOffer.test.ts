import { describe, expect, it } from 'vitest';

import { currentRebookMinutes, rebookOfferState } from '../../src/app/booking/rebookOffer';

const profile = {
  services: [{ id: 'facial', name: 'Facial', durationMinutes: 60 }],
  addOns: [{ id: 'mask', name: 'Mask', minutes: 15 }],
  booking: { maxGuests: 2 as const },
};

describe('rebook offer eligibility', () => {
  it('keeps the exact offer when service, add-ons and guests are still bookable', () => {
    expect(rebookOfferState(profile, 'facial', ['mask'], 2)).toBe('ready');
    expect(currentRebookMinutes(profile, 'facial', ['mask'], 2)).toBe(195);
  });

  it('does not silently reduce a manual visit with three or four guests', () => {
    expect(rebookOfferState(profile, 'facial', [], 3)).toBe('guests');
    expect(rebookOfferState(profile, 'facial', [], 4)).toBe('guests');
  });

  it('does not offer a removed service or add-on', () => {
    expect(rebookOfferState(profile, 'retired', [], 0)).toBe('offer');
    expect(rebookOfferState(profile, 'facial', ['retired'], 0)).toBe('offer');
  });

  it('does not offer a visit longer than the server maximum', () => {
    expect(rebookOfferState({ ...profile, services: [{ id: 'long', name: 'Long', durationMinutes: 300 }] },
      'long', [], 2)).toBe('offer');
  });
});
