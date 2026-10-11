import { describe, expect, it } from 'vitest';

import { LOCALES } from '../../src/contracts/common.js';
import { buildIcs, escapeIcsText, foldLine } from '../../src/lib/ics.js';

const base = {
  bookingId: 'abc123',
  serviceName: 'Brazilian Glow',
  professionalName: 'Maria Souza',
  city: 'Sao Paulo',
  startsAt: Date.parse('2026-10-03T13:00:00.000Z'),
  endsAt: Date.parse('2026-10-03T14:30:00.000Z'),
  tentative: false,
  link: 'https://bellohub.app/maria',
  now: Date.parse('2026-10-01T15:00:00.000Z'),
  locale: 'en' as const
};

const lines = (text: string): string[] => text.split('\r\n');

describe('buildIcs', () => {
  it('is a calendar with one event, CRLF line endings and the times in UTC', () => {
    const ics = buildIcs(base);

    expect(ics.endsWith('\r\n')).toBe(true);
    expect(ics).not.toMatch(/[^\r]\n/);
    expect(lines(ics)).toEqual(expect.arrayContaining([
      'BEGIN:VCALENDAR', 'VERSION:2.0', 'BEGIN:VEVENT', 'UID:booking-abc123@bellohub.app',
      'DTSTAMP:20261001T150000Z', 'DTSTART:20261003T130000Z', 'DTEND:20261003T143000Z',
      'SUMMARY:Brazilian Glow - Maria Souza', 'LOCATION:Sao Paulo', 'STATUS:CONFIRMED', 'END:VEVENT', 'END:VCALENDAR'
    ]));
    expect(lines(ics).filter((line) => line === 'BEGIN:VEVENT')).toHaveLength(1);
  });

  it('carries her booking page (D50: never the manage link) and a reminder a day before, and nothing clinical', () => {
    const ics = buildIcs(base);

    expect(ics).toContain('URL:https://bellohub.app/maria');
    expect(ics).not.toContain('/m/');
    expect(ics).toContain('TRIGGER:-PT24H');
    expect(ics).not.toMatch(/allerg|health|consent/i);
  });

  it('puts her address in LOCATION and its map link in the description when the client may see it', () => {
    const map = 'https://www.google.com/maps/search/?api=1&query=Rua%20Augusta%201200';
    const ics = buildIcs({ ...base, address: 'Rua Augusta 1200, São Paulo 01304-001', mapUrl: map });
    const unfolded = ics.replace(/\r\n /g, '');

    expect(unfolded).toContain('LOCATION:Rua Augusta 1200\\, São Paulo 01304-001');
    expect(unfolded).not.toContain('LOCATION:Sao Paulo');
    expect(unfolded).toContain(`\\n${map}`);
  });

  it('marks a booking that waits for the professional as tentative', () => {
    expect(buildIcs({ ...base, tentative: true })).toContain('STATUS:TENTATIVE');
  });

  it('escapes commas, semicolons, backslashes and line breaks', () => {
    expect(escapeIcsText('a,b;c\\d\ne')).toBe('a\\,b\\;c\\\\d\\ne');
    const ics = buildIcs({ ...base, serviceName: 'Facial, deluxe; special' });
    expect(ics).toContain('SUMMARY:Facial\\, deluxe\\; special - Maria Souza');
  });

  it('keeps no physical line longer than 75 octets and never splits a character', () => {
    const ics = buildIcs({ ...base, serviceName: 'Tratamento facial completo com limpeza profunda e hidratação intensiva', professionalName: 'Maria da Conceição Aparecida' });
    const encoder = new TextEncoder();

    for (const line of lines(ics)) expect(encoder.encode(line).length).toBeLessThanOrEqual(75);
    const unfolded = ics.replace(/\r\n /g, '');
    expect(unfolded).toContain('Tratamento facial completo com limpeza profunda e hidratação intensiva');
  });

  it('folds multi-byte text without breaking a character', () => {
    const text = `X:${'ç'.repeat(80)}`;
    const folded = foldLine(text);

    expect(folded.length).toBeGreaterThan(1);
    expect(folded.map((part, index) => (index === 0 ? part : part.slice(1))).join('')).toBe(text);
    for (const part of folded) expect(new TextEncoder().encode(part).length).toBeLessThanOrEqual(75);
  });

  it('isolates names in Arabic so they cannot scramble the line', () => {
    const ics = buildIcs({ ...base, locale: 'ar', professionalName: 'ماريا' });

    expect(ics).toContain(`⁨ماريا⁩`);
  });

  it('is deterministic for the same booking, so a calendar app updates instead of duplicating', () => {
    expect(buildIcs(base)).toBe(buildIcs(base));
    expect(buildIcs({ ...base, startsAt: base.startsAt + 3_600_000 })).toContain('UID:booking-abc123@bellohub.app');
  });
});

// S11: a calendar file per localization. The names are the kind each market writes (Turkish dotted capitals,
// Devanagari, Arabic), long enough to be folded, and the file must stay valid RFC 5545 in every one.
describe('buildIcs in every localization', () => {
  const names: Record<string, { service: string; professional: string }> = {
    tr: { service: 'İpek kirpik lifting ve bakım uygulaması', professional: 'İlknur Şahin' },
    hi: { service: 'हाइड्राफ़ेशियल और गहरी सफ़ाई वाला फ़ेशियल', professional: 'प्रिया शर्मा' },
    ar: { service: 'تنظيف البشرة العميق مع الترطيب المكثف', professional: 'نورة العتيبي' },
    de: { service: 'Wimpernlifting mit Färbung und Pflegebehandlung', professional: 'Jürgen Weiß' }
  };

  it.each(LOCALES)('%s: CRLF lines of at most 75 octets, the service and the name intact, isolates only in Arabic', (locale) => {
    const chosen = names[locale] ?? { service: 'Limpeza de pele profunda com hidratação intensiva', professional: 'Conceição Araújo' };
    const ics = buildIcs({ ...base, locale, serviceName: chosen.service, professionalName: chosen.professional });
    const encoder = new TextEncoder();

    expect(ics.startsWith('BEGIN:VCALENDAR\r\n')).toBe(true);
    expect(ics).not.toMatch(/[^\r]\n/);
    for (const line of lines(ics)) expect(encoder.encode(line).length).toBeLessThanOrEqual(75);
    const unfolded = ics.replace(/\r\n /g, '');
    expect(unfolded).toContain(chosen.service);
    expect(unfolded).toContain(chosen.professional);
    expect(unfolded.includes('\u2068')).toBe(locale === 'ar');
    expect(unfolded).toContain('DTSTART:20261003T130000Z');
  });
});
