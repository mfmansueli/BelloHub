// Time and price of a booking (D19): add-ons add time, and guests come in sequence, so the visit occupies the
// total. A price is information only (no payment exists anywhere in the product) and is shown only if she shows it.

import type { PublicAddOn, PublicService } from '../../api/types';

export type PriceSummary =
  | { readonly kind: 'amount'; readonly amount: number }
  | { readonly kind: 'startingFrom'; readonly amount: number }
  | { readonly kind: 'onRequest' };

export interface Totals {
  /** Minutes for one person: the service plus her add-ons. */
  readonly perPersonMinutes: number;
  /** Minutes the visit occupies: one person after another. */
  readonly totalMinutes: number;
  readonly people: number;
  readonly price: PriceSummary | null;
}

export function servicePrice(service: PublicService): PriceSummary | null {
  switch (service.priceDisplay) {
    case 'hide':
      return null;
    case 'onRequest':
      return { kind: 'onRequest' };
    case 'show':
      return service.priceAmount === undefined ? null : { kind: 'amount', amount: service.priceAmount };
    case 'startingFrom':
      return service.priceAmount === undefined ? { kind: 'onRequest' } : { kind: 'startingFrom', amount: service.priceAmount };
  }
}

export function totals(service: PublicService, addOns: readonly PublicAddOn[], guests: number): Totals {
  const perPersonMinutes = service.durationMinutes + addOns.reduce((sum, addOn) => sum + addOn.minutes, 0);
  const people = 1 + Math.max(0, guests);
  const base = servicePrice(service);
  let price: PriceSummary | null = base;
  if (base !== null && base.kind !== 'onRequest') {
    const perPerson = base.amount + addOns.reduce((sum, addOn) => sum + (addOn.priceAmount ?? 0), 0);
    price = { kind: base.kind, amount: perPerson * people };
  }
  return { perPersonMinutes, totalMinutes: perPersonMinutes * people, people, price };
}

/** The selected add-ons of a draft, in the order the professional offers them, ignoring ids that no longer exist. */
export function selectedAddOns(all: readonly PublicAddOn[], ids: readonly string[]): PublicAddOn[] {
  return all.filter((addOn) => ids.includes(addOn.id));
}
