// The words for a price, in the page language and the business currency. A price is information only.

import type { PriceDisplay } from '../../api/types';
import type { Formatter } from '../../lib/format';
import type { Translate } from '../../i18n';
import type { PriceSummary } from './summary';

export function priceText(price: PriceSummary | null, format: Formatter, t: Translate): string {
  if (price === null) return '';
  switch (price.kind) {
    case 'amount':
      return format.money(price.amount);
    case 'startingFrom':
      return t('price.from', { price: format.money(price.amount) });
    case 'onRequest':
      return t('price.onRequest');
  }
}

/** The price block of a booking as the server describes it (`BookingView.price`). */
export function bookedPriceText(
  price: { display: Exclude<PriceDisplay, 'hide'>; amount?: number; currency: string } | undefined,
  format: Formatter,
  t: Translate,
): string {
  if (price === undefined) return '';
  if (price.display === 'onRequest' || price.amount === undefined) return t('price.onRequest');
  const money = format.money(price.amount, price.currency);
  return price.display === 'startingFrom' ? t('price.from', { price: money }) : money;
}
