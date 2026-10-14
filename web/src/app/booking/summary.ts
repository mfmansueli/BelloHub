// Time and price of a booking (D19): add-ons add time, and guests come in sequence, so the visit occupies the
// total. A price is information only (no payment exists anywhere in the product) and is shown only if she shows it.
// An add-on's price is free text (`priceText`, API.md section 4) and is never added to the service price.

import type { PublicAddOn, PublicService } from '../../api/types';

export type PriceSummary =
  | { readonly kind: 'amount'; readonly amount: number }
  | { readonly kind: 'startingFrom'; readonly amount: number }
  | { readonly kind: 'onRequest' };

export interface Totals {
  /** Minutes for the first person: the service plus the selected add-ons. */
  readonly perPersonMinutes: number;
  /** Minutes the visit occupies: one person after another. */
  readonly totalMinutes: number;
  readonly people: number;
  readonly price: PriceSummary | null;
}

export function servicePrice(service: PublicService): PriceSummary | null {
  const price = service.price;
  if (price === undefined) return null;
  switch (price.display) {
    case 'onRequest':
      return { kind: 'onRequest' };
    case 'show':
      return price.amount === undefined ? null : { kind: 'amount', amount: price.amount };
    case 'startingFrom':
      return price.amount === undefined ? { kind: 'onRequest' } : { kind: 'startingFrom', amount: price.amount };
  }
}

export function totals(service: PublicService, addOns: readonly PublicAddOn[], guests: number): Totals {
  const perPersonMinutes = service.durationMinutes + addOns.reduce((sum, addOn) => sum + addOn.minutes, 0);
  const people = 1 + Math.max(0, guests);
  const base = servicePrice(service);
  let price: PriceSummary | null = base;
  if (base !== null && base.kind !== 'onRequest') price = { kind: base.kind, amount: base.amount * people };
  return { perPersonMinutes, totalMinutes: service.durationMinutes * people +
    addOns.reduce((sum, addOn) => sum + addOn.minutes, 0), people, price };
}

/** The selected add-ons of a draft, in the order the professional offers them, ignoring ids that no longer exist. */
export function selectedAddOns(all: readonly PublicAddOn[], ids: readonly string[]): PublicAddOn[] {
  return all.filter((addOn) => ids.includes(addOn.id));
}
