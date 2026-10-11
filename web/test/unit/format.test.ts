import { describe, expect, it } from 'vitest';

import { Formatter, intlTag, type FormatContext } from '../../src/lib/format';
import { LOCALE_IDS, type LocaleId } from '../../src/lib/locales';

// Expected values are generated from Intl with the same locale (docs/07 section 2.4: nothing is asserted from
// memory), plus a short list of hand-verified quirks that pin the rules the page depends on.

const INSTANT = Date.parse('2026-10-01T18:00:00Z'); // 15:00 in São Paulo

function context(localeId: LocaleId, overrides: Partial<FormatContext> = {}): FormatContext {
  return { localeId, regionCode: 'BR', timeZone: 'America/Sao_Paulo', currency: 'BRL', ...overrides };
}

describe('Formatter, every localization', () => {
  for (const id of LOCALE_IDS) {
    it(`${id}: time, dates, money, minutes and lists come from Intl in the business zone`, () => {
      const f = new Formatter(context(id));
      const tag = intlTag(id, 'BR');
      expect(f.time(INSTANT)).toBe(
        new Intl.DateTimeFormat(tag, { timeZone: 'America/Sao_Paulo', hour: 'numeric', minute: '2-digit', hourCycle: 'h23' }).format(INSTANT),
      );
      expect(f.longDate(INSTANT)).toBe(
        new Intl.DateTimeFormat(tag, { timeZone: 'America/Sao_Paulo', weekday: 'long', month: 'long', day: 'numeric' }).format(INSTANT),
      );
      expect(f.money(120)).toBe(new Intl.NumberFormat(tag, { style: 'currency', currency: 'BRL', minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(120));
      expect(f.money(70.5)).toBe(new Intl.NumberFormat(tag, { style: 'currency', currency: 'BRL', minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(70.5));
      expect(f.minutes(90)).toBe(new Intl.NumberFormat(tag, { style: 'unit', unit: 'minute', unitDisplay: 'short' }).format(90));
      expect(f.list(['A', 'B', 'C'])).toBe(new Intl.ListFormat(tag, { style: 'long', type: 'conjunction' }).format(['A', 'B', 'C']));
      expect(f.weekdayHeaders(0)).toHaveLength(7);
    });
  }
});

describe('Formatter, hand-verified quirks', () => {
  it('shows the business clock, not the device clock: 15:00 for São Paulo whatever the reader language', () => {
    expect(new Formatter(context('en')).time(INSTANT)).toBe('15:00');
    expect(new Formatter(context('pt-BR')).time(INSTANT)).toBe('15:00');
  });

  it('uses 12 hours where the business region does (United States)', () => {
    const f = new Formatter(context('en', { regionCode: 'US', timeZone: 'America/New_York', currency: 'USD' }));
    expect(f.time(INSTANT)).toMatch(/^2:00\s?PM$/);
  });

  it('honours her override of the clock and the week start (D25)', () => {
    const twelve = new Formatter(context('en', { use24Hour: false }));
    expect(twelve.time(INSTANT)).toMatch(/^3:00\s?PM$/);
    expect(twelve.clock.hourCycle).toBe('h12');
    const monday = new Formatter(context('en', { weekStart: 1 }));
    expect(monday.clock.firstDay).toBe(1);
    expect(new Formatter(context('en', { regionCode: 'US', use24Hour: true })).time(INSTANT)).toBe('15:00');
  });

  it('a Lisbon evening is the next UTC day but the same civil day', () => {
    const f = new Formatter(context('pt-PT', { regionCode: 'PT', timeZone: 'Europe/Lisbon', currency: 'EUR' }));
    expect(f.time(Date.parse('2026-07-01T22:30:00Z'))).toBe('23:30');
    expect(f.dayMonth(Date.parse('2026-07-01T22:30:00Z'))).toBe(new Intl.DateTimeFormat('pt-PT', { timeZone: 'Europe/Lisbon', month: 'long', day: 'numeric' }).format(Date.parse('2026-07-01T22:30:00Z')));
  });

  it('a weekday and date reads "Thursday · October 1" in English', () => {
    expect(new Formatter(context('en')).weekdayDate(INSTANT)).toBe('Thursday · October 1');
  });

  it('money has no decimals for whole amounts, two for the rest, in the business currency', () => {
    const f = new Formatter(context('en'));
    expect(f.money(120)).toBe('R$120');
    expect(f.money(70.5)).toBe('R$70.50');
    expect(f.money(14.99, 'EUR')).toBe('€14.99');
  });

  it('keeps Arabic-Indic digits for Saudi Arabia and Western digits for the Emirates, as Intl decides', () => {
    const sa = new Formatter(context('ar', { regionCode: 'SA', timeZone: 'Asia/Riyadh', currency: 'SAR' }));
    const ae = new Formatter(context('ar', { regionCode: 'AE', timeZone: 'Asia/Dubai', currency: 'AED' }));
    expect(sa.tag).toBe('ar-SA');
    expect(ae.tag).toBe('ar-AE');
    expect(sa.number(1234)).toBe(new Intl.NumberFormat('ar-SA').format(1234));
    expect(ae.number(1234)).toBe(new Intl.NumberFormat('ar-AE').format(1234));
  });

  it('Arabic from a Brazilian business keeps the plain `ar` tag', () => {
    expect(new Formatter(context('ar')).tag).toBe('ar');
  });

  it('formats a countdown with the language digits', () => {
    expect(new Formatter(context('en')).countdown(24)).toBe('0:24');
    expect(new Formatter(context('en')).countdown(95)).toBe('1:35');
    expect(new Formatter(context('en')).countdown(-3)).toBe('0:00');
    const arabic = new Formatter(context('ar')).countdown(24);
    expect(arabic).toBe(`${new Intl.NumberFormat('ar', { useGrouping: false }).format(0)}:${new Intl.NumberFormat('ar', { minimumIntegerDigits: 2, useGrouping: false }).format(24)}`);
  });

  it('calendar headers start on the requested weekday', () => {
    const f = new Formatter(context('en'));
    expect(f.weekdayHeaders(0).map((h) => h.full)).toEqual(['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']);
    expect(f.weekdayHeaders(1)[0]?.full).toBe('Monday');
    expect(f.weekdayHeaders(6)[0]?.full).toBe('Saturday');
  });

  it('formats a civil date without letting the time zone move it', () => {
    const f = new Formatter(context('en', { timeZone: 'Pacific/Auckland' }));
    expect(f.longDateOf('2026-10-01')).toBe('Thursday, October 1');
    expect(f.monthYear(2026, 10)).toBe('October 2026');
    expect(f.weekdayShortOf('2026-10-01')).toBe('Thu');
  });

  it('picks the plural category with the language rules (Arabic has six forms)', () => {
    const ar = new Formatter(context('ar'));
    expect([0, 1, 2, 3, 11, 100].map((n) => ar.pluralCategory(n))).toEqual(['zero', 'one', 'two', 'few', 'many', 'other']);
    const en = new Formatter(context('en'));
    expect([0, 1, 2].map((n) => en.pluralCategory(n))).toEqual(['other', 'one', 'other']);
  });
});
