// The fourteen localizations (docs/07-LOCALIZATION.md section 1) and how a page picks one.

export const LOCALE_IDS = [
  'pt-BR',
  'pt-PT',
  'es-MX',
  'es-419',
  'es',
  'en',
  'en-GB',
  'it',
  'fr',
  'de',
  'tr',
  'id',
  'hi',
  'ar',
] as const;

export type LocaleId = (typeof LOCALE_IDS)[number];

/** The twelve languages written by hand; `es-419` and `en-GB` are derived by `scripts/derive-locales.py`. */
export const AUTHORED_LOCALE_IDS: readonly LocaleId[] = LOCALE_IDS.filter((id) => id !== 'es-419' && id !== 'en-GB');

export const DEFAULT_LOCALE: LocaleId = 'en';

/** Each language in its own name, for the language chooser (never translated). */
export const AUTONYMS: Readonly<Record<LocaleId, string>> = {
  'pt-BR': 'Português (Brasil)',
  'pt-PT': 'Português (Portugal)',
  'es-MX': 'Español (México)',
  'es-419': 'Español (Latinoamérica)',
  es: 'Español (España)',
  en: 'English (US)',
  'en-GB': 'English (UK)',
  it: 'Italiano',
  fr: 'Français',
  de: 'Deutsch',
  tr: 'Türkçe',
  id: 'Bahasa Indonesia',
  hi: 'हिन्दी',
  ar: 'العربية',
};

/** Short label on the chooser button. */
export function shortLabel(id: LocaleId): string {
  return id.toUpperCase();
}

export function isLocaleId(value: unknown): value is LocaleId {
  return typeof value === 'string' && (LOCALE_IDS as readonly string[]).includes(value);
}

export function languageOf(id: LocaleId): string {
  return id.split('-')[0] ?? id;
}

export type Direction = 'ltr' | 'rtl';

export function directionOf(id: LocaleId): Direction {
  return languageOf(id) === 'ar' ? 'rtl' : 'ltr';
}

const LATIN_AMERICAN_REGIONS = new Set([
  'AR', 'BO', 'CL', 'CO', 'CR', 'CU', 'DO', 'EC', 'GT', 'HN', 'NI', 'PA', 'PE', 'PR', 'PY', 'SV', 'UY', 'VE', '419',
]);

const BRITISH_ENGLISH_REGIONS = new Set(['GB', 'IE', 'AU', 'NZ', 'ZA', 'IN', 'SG', 'MY', 'HK', 'NG', 'KE', 'PK', 'AE', 'SA']);

/**
 * Maps one BCP 47 tag from `navigator.languages` to the localization the product would use for it, or null
 * for a language it does not speak. Same rules as the iOS `AppLocalization.resolve` (docs/07 section 2.2):
 * Portuguese without a region or from Brazil is `pt-BR`, other Portuguese is `pt-PT`; Spanish from Spain is
 * `es`, from Mexico or the United States `es-MX`, from the rest of Latin America `es-419`; English from
 * British-spelling regions is `en-GB`; French, German, Arabic and the rest have one voice.
 */
export function resolveTag(tag: string): LocaleId | null {
  const parts = tag.replace(/_/g, '-').split('-');
  const language = (parts[0] ?? '').toLowerCase();
  const region = parts.slice(1).find((part) => /^[A-Za-z]{2}$|^\d{3}$/.test(part))?.toUpperCase();
  switch (language) {
    case 'pt':
      return region === undefined || region === 'BR' ? 'pt-BR' : 'pt-PT';
    case 'es':
      if (region === undefined || region === 'ES') return 'es';
      if (region === 'MX' || region === 'US') return 'es-MX';
      return LATIN_AMERICAN_REGIONS.has(region) ? 'es-419' : 'es';
    case 'en':
      return region !== undefined && BRITISH_ENGLISH_REGIONS.has(region) ? 'en-GB' : 'en';
    case 'it':
    case 'fr':
    case 'de':
    case 'tr':
    case 'id':
    case 'hi':
    case 'ar':
      return language;
    default:
      return null;
  }
}

/** The closest offered localization to what `resolveTag` returned (an offered `es` can serve `es-419`). */
function closestOffered(wanted: LocaleId, offered: readonly LocaleId[]): LocaleId | null {
  if (offered.includes(wanted)) return wanted;
  const language = languageOf(wanted);
  const fallbacks: Partial<Record<LocaleId, LocaleId[]>> = {
    'es-419': ['es-MX', 'es'],
    'es-MX': ['es-419', 'es'],
    es: ['es-MX', 'es-419'],
    'en-GB': ['en'],
    en: ['en-GB'],
    'pt-BR': ['pt-PT'],
    'pt-PT': ['pt-BR'],
  };
  for (const candidate of fallbacks[wanted] ?? []) {
    if (offered.includes(candidate)) return candidate;
  }
  return offered.find((id) => languageOf(id) === language) ?? null;
}

export interface LocaleChoice {
  /** The language the client chose in the chooser (stored in localStorage), if any. */
  stored?: string | null;
  /** `navigator.languages`. */
  preferred: readonly string[];
  /** The localizations this professional offers. Empty means "all fourteen". */
  offered: readonly LocaleId[];
  /** Her default page language. */
  fallback: LocaleId;
}

/**
 * Selection order (docs/07 section 7): the explicit choice, then `navigator.languages` matched to what the
 * professional offers, then her default.
 */
export function chooseLocale(choice: LocaleChoice): LocaleId {
  const offered = choice.offered.length > 0 ? choice.offered : LOCALE_IDS;
  if (isLocaleId(choice.stored) && offered.includes(choice.stored)) return choice.stored;
  for (const tag of choice.preferred) {
    const wanted = resolveTag(tag);
    if (wanted === null) continue;
    const match = closestOffered(wanted, offered);
    if (match !== null) return match;
  }
  return offered.includes(choice.fallback) ? choice.fallback : (offered[0] ?? DEFAULT_LOCALE);
}

/** Candidate localizations for a professional-supplied text map, best first. */
export function fallbackChain(id: LocaleId, pageDefault: LocaleId = DEFAULT_LOCALE): LocaleId[] {
  const chain: LocaleId[] = [id];
  const language = languageOf(id);
  const parent: Partial<Record<LocaleId, LocaleId>> = { 'es-419': 'es-MX', 'en-GB': 'en' };
  const up = parent[id];
  if (up !== undefined) chain.push(up);
  for (const other of LOCALE_IDS) {
    if (languageOf(other) === language && !chain.includes(other)) chain.push(other);
  }
  for (const extra of [pageDefault, 'en'] as const) {
    if (!chain.includes(extra)) chain.push(extra);
  }
  return chain;
}

/** A text the professional published once per localization (bio, headline, form labels, rules). */
export type LocalizedText = Readonly<Partial<Record<string, string>>>;

/** Picks the best text for `id`; returns the language it actually used so the page can set `lang` on it. */
export function pickLocalized(
  texts: LocalizedText | undefined,
  id: LocaleId,
  pageDefault: LocaleId = DEFAULT_LOCALE,
): { text: string; lang: string } | null {
  if (texts === undefined) return null;
  for (const candidate of fallbackChain(id, pageDefault)) {
    const text = texts[candidate];
    if (text !== undefined && text !== '') return { text, lang: candidate };
  }
  for (const [lang, text] of Object.entries(texts)) {
    if (text !== undefined && text !== '') return { text, lang };
  }
  return null;
}
