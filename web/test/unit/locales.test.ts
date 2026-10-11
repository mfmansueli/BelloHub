import { describe, expect, it } from 'vitest';

import {
  AUTHORED_LOCALE_IDS,
  AUTONYMS,
  LOCALE_IDS,
  chooseLocale,
  directionOf,
  fallbackChain,
  pickLocalized,
  resolveTag,
  type LocaleId,
} from '../../src/lib/locales';

describe('the fourteen localizations', () => {
  it('are fourteen, twelve of them authored, and each has an autonym', () => {
    expect(LOCALE_IDS).toHaveLength(14);
    expect(AUTHORED_LOCALE_IDS).toHaveLength(12);
    expect(AUTHORED_LOCALE_IDS).not.toContain('es-419');
    expect(AUTHORED_LOCALE_IDS).not.toContain('en-GB');
    for (const id of LOCALE_IDS) expect(AUTONYMS[id].length).toBeGreaterThan(1);
  });

  it('only Arabic is right-to-left', () => {
    for (const id of LOCALE_IDS) expect(directionOf(id)).toBe(id === 'ar' ? 'rtl' : 'ltr');
  });
});

describe('resolveTag (same rules as the iOS AppLocalization.resolve, docs/07 section 2.2)', () => {
  const cases: [string, LocaleId | null][] = [
    ['pt', 'pt-BR'], ['pt-BR', 'pt-BR'], ['pt-PT', 'pt-PT'], ['pt-AO', 'pt-PT'], ['pt-MZ', 'pt-PT'],
    ['es', 'es'], ['es-ES', 'es'], ['es-MX', 'es-MX'], ['es-US', 'es-MX'], ['es-AR', 'es-419'], ['es-CO', 'es-419'], ['es-419', 'es-419'],
    ['en', 'en'], ['en-US', 'en'], ['en-CA', 'en'], ['en-GB', 'en-GB'], ['en-AU', 'en-GB'], ['en-IN', 'en-GB'], ['en-ZA', 'en-GB'], ['en-NZ', 'en-GB'], ['en-IE', 'en-GB'],
    ['fr-BE', 'fr'], ['fr-CA', 'fr'], ['fr-CH', 'fr'], ['de-AT', 'de'], ['de-CH', 'de'], ['it-CH', 'it'],
    ['ar-SA', 'ar'], ['ar-AE', 'ar'], ['ar-EG', 'ar'], ['hi-IN', 'hi'], ['tr-TR', 'tr'], ['id-ID', 'id'],
    ['ja', null], ['zh-Hans-CN', null], ['ru', null],
  ];
  for (const [tag, expected] of cases) {
    it(`${tag} -> ${expected ?? 'none'}`, () => {
      expect(resolveTag(tag)).toBe(expected);
    });
  }

  it('reads a script subtag and underscores', () => {
    expect(resolveTag('sr_Latn_RS')).toBeNull();
    expect(resolveTag('en_GB')).toBe('en-GB');
    expect(resolveTag('es-Latn-MX')).toBe('es-MX');
  });
});

describe('chooseLocale (docs/07 section 7: explicit choice, then navigator.languages, then her default)', () => {
  const offered: LocaleId[] = ['pt-BR', 'en'];

  it('an explicit choice wins when she offers it', () => {
    expect(chooseLocale({ stored: 'en', preferred: ['pt-BR'], offered, fallback: 'pt-BR' })).toBe('en');
  });

  it('ignores a stored language she does not offer, or garbage', () => {
    expect(chooseLocale({ stored: 'fr', preferred: ['pt-BR'], offered, fallback: 'en' })).toBe('pt-BR');
    expect(chooseLocale({ stored: '<script>', preferred: ['en-US'], offered, fallback: 'pt-BR' })).toBe('en');
  });

  it('matches navigator.languages in order against what she offers', () => {
    expect(chooseLocale({ preferred: ['ja', 'en-US', 'pt-BR'], offered, fallback: 'pt-BR' })).toBe('en');
    expect(chooseLocale({ preferred: ['pt-PT', 'en'], offered, fallback: 'en' })).toBe('pt-BR');
  });

  it('serves a close relative when the exact language is not offered', () => {
    expect(chooseLocale({ preferred: ['es-AR'], offered: ['es-MX', 'en'], fallback: 'en' })).toBe('es-MX');
    expect(chooseLocale({ preferred: ['en-GB'], offered: ['en', 'pt-BR'], fallback: 'pt-BR' })).toBe('en');
    expect(chooseLocale({ preferred: ['pt-PT'], offered: ['pt-BR'], fallback: 'pt-BR' })).toBe('pt-BR');
  });

  it('falls back to her default, then to the first offered', () => {
    expect(chooseLocale({ preferred: ['ja'], offered, fallback: 'en' })).toBe('en');
    expect(chooseLocale({ preferred: ['ja'], offered, fallback: 'fr' })).toBe('pt-BR');
  });

  it('an empty offered list means all fourteen', () => {
    expect(chooseLocale({ preferred: ['ar-SA'], offered: [], fallback: 'en' })).toBe('ar');
  });
});

describe('professional-supplied text in several languages', () => {
  it('prefers the exact localization, then its relatives, then her default, then English', () => {
    expect(fallbackChain('es-419', 'pt-BR').slice(0, 3)).toEqual(['es-419', 'es-MX', 'es']);
    expect(fallbackChain('en-GB', 'pt-BR')[1]).toBe('en');
    expect(fallbackChain('ar', 'pt-BR')).toEqual(['ar', 'pt-BR', 'en']);
  });

  it('picks text and tells which language it used', () => {
    const texts = { 'pt-BR': 'Olá', en: 'Hello' };
    expect(pickLocalized(texts, 'en', 'pt-BR')).toEqual({ text: 'Hello', lang: 'en' });
    expect(pickLocalized(texts, 'fr', 'pt-BR')).toEqual({ text: 'Olá', lang: 'pt-BR' });
    expect(pickLocalized(texts, 'en-GB', 'pt-BR')).toEqual({ text: 'Hello', lang: 'en' });
    expect(pickLocalized({ de: 'Hallo' }, 'ar', 'pt-BR')).toEqual({ text: 'Hallo', lang: 'de' });
    expect(pickLocalized({ en: '' }, 'en')).toBeNull();
    expect(pickLocalized(undefined, 'en')).toBeNull();
  });
});
