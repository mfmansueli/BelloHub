// The translation function, pure (no DOM, no state), so it is tested without a page.
//
// A catalog maps a semantic key (`bk1.book`) to a string, or, for plurals, to an object with one string per
// CLDR plural category (`one`, `other`, and for Arabic also `zero`, `two`, `few`, `many`). Placeholders are
// `{name}`. In right-to-left languages every interpolated value is wrapped in a Unicode isolate so a Latin name
// or a time cannot scramble the sentence: strings isolate by their own first strong character, numbers and
// values marked with `ltr()` as left-to-right (docs/07-LOCALIZATION.md section 2.5 and 7).

import { FSI, LRI, Ltr, PDI } from '../lib/bidi';

export type PluralForms = Readonly<Partial<Record<Intl.LDMLPluralRule, string>>>;
export type Message = string | PluralForms;
export type Catalog = Readonly<Record<string, Message>>;
export type Param = string | number | Ltr;
export type Params = Readonly<Record<string, Param>>;

export interface TranslateContext {
  /** Wrap interpolated values in isolates (right-to-left languages). */
  readonly isolate: boolean;
  readonly pluralCategory: (count: number) => Intl.LDMLPluralRule;
  /** The language's own number formatting, for `{count}` and any number parameter. */
  readonly formatNumber: (value: number) => string;
}

function render(value: Param, context: TranslateContext): string {
  if (value instanceof Ltr) return context.isolate ? `${LRI}${value.value}${PDI}` : value.value;
  if (typeof value === 'number') {
    const text = context.formatNumber(value);
    return context.isolate ? `${LRI}${text}${PDI}` : text;
  }
  return context.isolate && value !== '' ? `${FSI}${value}${PDI}` : value;
}

export function interpolate(template: string, params: Params | undefined, context: TranslateContext): string {
  if (params === undefined) return template;
  return template.replace(/\{(\w+)\}/g, (placeholder, name: string) => {
    const value = params[name];
    return value === undefined ? placeholder : render(value, context);
  });
}

/** The text for `key`, or the key itself when the catalog lacks it (a bug the i18n check prevents). */
export function translate(catalog: Catalog, key: string, params: Params | undefined, context: TranslateContext): string {
  const message = catalog[key];
  if (message === undefined) return key;
  if (typeof message === 'string') return interpolate(message, params, context);
  const count = params?.['count'];
  const category = typeof count === 'number' ? context.pluralCategory(count) : 'other';
  const form = message[category] ?? message.other ?? '';
  return interpolate(form, params, context);
}

/** The placeholders a template uses, for the checker and for tests. */
export function placeholdersOf(template: string): string[] {
  return [...new Set([...template.matchAll(/\{(\w+)\}/g)].map((match) => match[1] ?? ''))].sort();
}
