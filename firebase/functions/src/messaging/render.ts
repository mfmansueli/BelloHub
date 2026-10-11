// Fills a template. Values are isolated for right-to-left text (docs/07 section 7: names, times and links inside
// Arabic must not scramble) and the date is formatted by Intl in the reader's language and the professional's
// time zone, never by hand (D25).

import type { LocaleId } from '../contracts/common.js';

export type TemplateVars = Partial<Record<'code' | 'professional' | 'service' | 'when' | 'link', string>>;

const FIRST_STRONG_ISOLATE = '⁨';
const POP_ISOLATE = '⁩';

export function isolate(value: string): string {
  return `${FIRST_STRONG_ISOLATE}${value}${POP_ISOLATE}`;
}

/**
 * Replaces `{name}` placeholders; an unknown or missing variable becomes an empty string, never "undefined". The link is
 * never isolated: every template puts it on its own line (its own paragraph, so it cannot reorder Arabic text), and an
 * isolate character next to an address can end up inside the link a mail app detects.
 */
export function fillTemplate(template: string, vars: TemplateVars, locale: LocaleId): string {
  const rtl = locale === 'ar';
  return template.replace(/\{(code|professional|service|when|link)\}/g, (_match, key: keyof TemplateVars) => {
    const value = vars[key] ?? '';
    return rtl && key !== 'link' && value.length > 0 ? isolate(value) : value;
  });
}

/** "Thursday, October 8, 15:00" in the reader's language, in the business time zone. */
export function formatWhen(instantMs: number, timeZone: string, locale: LocaleId): string {
  // Latin digits everywhere: times and phone numbers stay left-to-right and readable inside Arabic text.
  const tag = locale === 'ar' || locale === 'hi' ? `${locale}-u-nu-latn` : locale;
  return new Intl.DateTimeFormat(tag, {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    hour: 'numeric',
    minute: '2-digit',
    timeZone
  }).format(new Date(instantMs));
}
