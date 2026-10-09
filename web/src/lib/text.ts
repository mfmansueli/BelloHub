// Picking the right published text for the page language, and keeping its language on the element.

import type { RuleLine } from '../api/types';
import { fallbackChain, type LocaleId } from './locales';

export interface Picked<T> {
  readonly value: T;
  /** The language the text is really in, so the element can say `lang` when it differs from the page. */
  readonly lang: string;
}

export function pickRules(
  rules: Readonly<Partial<Record<string, readonly RuleLine[]>>> | undefined,
  locale: LocaleId,
  pageDefault: LocaleId,
): Picked<readonly RuleLine[]> | null {
  if (rules === undefined) return null;
  for (const candidate of fallbackChain(locale, pageDefault)) {
    const lines = rules[candidate];
    if (lines !== undefined && lines.length > 0) return { value: lines, lang: candidate };
  }
  return null;
}

/** The `lang` attribute for text that is not in the page language (undefined when it is). */
export function langAttribute(picked: { lang: string } | null, locale: LocaleId): string | undefined {
  return picked === null || picked.lang === locale ? undefined : picked.lang;
}
