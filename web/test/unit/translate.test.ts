import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { describe, expect, it } from 'vitest';

import { FSI, LRI, PDI, ltr } from '../../src/lib/bidi';
import { LOCALE_IDS, type LocaleId } from '../../src/lib/locales';
import { makeTranslate } from '../../src/i18n';
import { placeholdersOf, translate, type Catalog, type TranslateContext } from '../../src/i18n/translate';

function context(locale: string, isolate: boolean): TranslateContext {
  const plural = new Intl.PluralRules(locale);
  const numbers = new Intl.NumberFormat(locale);
  return { isolate, pluralCategory: (count) => plural.select(count), formatNumber: (value) => numbers.format(value) };
}

function catalogOf(locale: LocaleId): Catalog {
  return JSON.parse(readFileSync(resolve(import.meta.dirname, `../../src/i18n/${locale}.json`), 'utf8')) as Catalog;
}

describe('translate', () => {
  const catalog: Catalog = {
    'greet': 'Hello, {name}.',
    'both': '{name} at {time}',
    'items': { one: '{count} item', other: '{count} items' },
    'nocount': { one: 'one item', other: '{count} items' },
  };

  it('fills placeholders and leaves an unknown one visible rather than silent', () => {
    expect(translate(catalog, 'greet', { name: 'Ana' }, context('en', false))).toBe('Hello, Ana.');
    expect(translate(catalog, 'greet', {}, context('en', false))).toBe('Hello, {name}.');
    expect(translate(catalog, 'greet', undefined, context('en', false))).toBe('Hello, {name}.');
  });

  it('returns the key itself for a key the catalog lacks (the i18n check prevents it)', () => {
    expect(translate(catalog, 'missing', undefined, context('en', false))).toBe('missing');
  });

  it('picks the plural form by the language rules and formats the count in that language', () => {
    expect(translate(catalog, 'items', { count: 1 }, context('en', false))).toBe('1 item');
    expect(translate(catalog, 'items', { count: 0 }, context('en', false))).toBe('0 items');
    expect(translate(catalog, 'items', { count: 1200 }, context('en', false))).toBe('1,200 items');
    expect(translate(catalog, 'nocount', { count: 1 }, context('en', false))).toBe('one item');
    expect(translate(catalog, 'nocount', { count: 5 }, context('en', false))).toBe('5 items');
  });

  it('adds Unicode isolates only in right-to-left, names by their first strong letter, numbers and times left-to-right', () => {
    const rtl = translate(catalog, 'both', { name: 'Maria Silva', time: ltr('14:30') }, context('ar', true));
    expect(rtl).toBe(`${FSI}Maria Silva${PDI} at ${LRI}14:30${PDI}`);
    const plain = translate(catalog, 'both', { name: 'Maria Silva', time: ltr('14:30') }, context('en', false));
    expect(plain).toBe('Maria Silva at 14:30');
    expect(translate(catalog, 'items', { count: 7 }, context('ar', true))).toContain(LRI);
  });

  it('does not wrap an empty value in isolates', () => {
    expect(translate(catalog, 'greet', { name: '' }, context('ar', true))).toBe('Hello, .');
  });

  it('lists the placeholders of a template', () => {
    expect(placeholdersOf('{b} and {a} and {b}')).toEqual(['a', 'b']);
    expect(placeholdersOf('none')).toEqual([]);
  });
});

describe('the real catalogs, rendered', () => {
  const sampleCounts = [0, 1, 2, 3, 6, 11, 25, 100, 102];

  it('every language renders every plural key for every count with no placeholder left over', () => {
    for (const locale of LOCALE_IDS) {
      const catalog = catalogOf(locale);
      const t = makeTranslate(catalog, locale);
      for (const [key, message] of Object.entries(catalog)) {
        if (typeof message === 'string') continue;
        for (const count of sampleCounts) {
          const text = t(key, { count, name: 'Maria', guest: 'Ana' });
          expect(text, `${locale} ${key} for ${count}`).not.toMatch(/[{}]/);
          expect(text.trim().length).toBeGreaterThan(0);
        }
      }
    }
  });

  it('Arabic uses its six plural categories and Indonesian only "other"', () => {
    const ar = new Intl.PluralRules('ar');
    expect([0, 1, 2, 3, 11, 100].map((n) => ar.select(n))).toEqual(['zero', 'one', 'two', 'few', 'many', 'other']);
    const arabic = catalogOf('ar')['bk11.count'];
    expect(typeof arabic).toBe('object');
    expect(Object.keys(arabic as object).sort()).toEqual(['few', 'many', 'one', 'other', 'two', 'zero']);
    const indonesian = catalogOf('id')['bk11.count'];
    expect(Object.keys(indonesian as object)).toEqual(['other']);
  });

  it('right-to-left output isolates the professional name and keeps the sentence readable in Arabic', () => {
    const t = makeTranslate(catalogOf('ar'), 'ar');
    const text = t('bk1.messageWa', { name: 'Maria Bello' });
    expect(text).toContain(`${FSI}Maria Bello${PDI}`);
    expect(makeTranslate(catalogOf('en'), 'en')('bk1.messageWa', { name: 'Maria Bello' })).not.toContain(FSI);
  });

  it('the count is written with the language digits only when the language does so', () => {
    const t = makeTranslate(catalogOf('en'), 'en');
    expect(t('bk11.count', { count: 3, name: 'Maria' })).toBe('3 upcoming appointments with Maria.');
  });
});
