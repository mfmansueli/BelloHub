// D49: the consent a client signs is the text the server returns in `getFormContext.consent` for that professional.
// The page never shows an embedded draft in its place; when the server returns no usable text the form is not
// available, and the page says so neutrally. Pure, so the rule has one owner and a test.

import type { ConsentText } from '../../api/types';
import { directionOf, fallbackChain, isLocaleId, type Direction, type LocaleId } from '../../lib/locales';

/** The text she will sign, the language it was written in (recorded with the acceptance) and its version. */
export interface SignableConsent {
  readonly textVersion: string;
  readonly localeId: LocaleId;
  readonly direction: Direction;
  /** The paragraphs of the text, in order. */
  readonly paragraphs: readonly string[];
}

/**
 * The consent to sign for the page language: the professional's text in that language, else the closest one she
 * published (same language, her default, English). A visit for a minor needs her `guardianText`. Null when she
 * published nothing usable: the page then offers no way to sign.
 */
export function signableConsent(
  consent: Readonly<Partial<Record<string, ConsentText>>>,
  locale: LocaleId,
  professionalDefault: LocaleId,
  forMinor: boolean,
): SignableConsent | null {
  for (const candidate of fallbackChain(locale, professionalDefault)) {
    const entry = consent[candidate];
    if (entry === undefined || !isLocaleId(candidate)) continue;
    const text = (forMinor ? entry.guardianText : entry.text)?.trim() ?? '';
    if (text === '' || entry.textVersion.trim() === '') continue;
    return {
      textVersion: entry.textVersion,
      localeId: candidate,
      direction: directionOf(candidate),
      paragraphs: text
        .split(/\n{2,}/)
        .map((paragraph) => paragraph.trim())
        .filter((paragraph) => paragraph !== ''),
    };
  }
  return null;
}
