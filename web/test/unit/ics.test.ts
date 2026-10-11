import { readFileSync } from 'node:fs';

import { describe, expect, it } from 'vitest';

import { makeTranslate } from '../../src/i18n';
import { buildIcs, calendarEvent, escapeIcsText, foldIcsLine, googleCalendarUrl, toIcsUtc, type CalendarEvent } from '../../src/lib/ics';
import { LOCALE_IDS } from '../../src/lib/locales';

const event: CalendarEvent = {
  uid: 'bk_7Hq2xkP9',
  startMs: Date.parse('2026-10-01T18:00:00Z'),
  endMs: Date.parse('2026-10-01T19:30:00Z'),
  summary: 'Brazilian Glow, with Maria Beauty',
  description: 'Book again or find your appointment: https://bellohub.app/maria\nFree changes until Wed, Sep 30 at 15:00.',
  location: 'São Paulo',
  language: 'en',
};

describe('iCalendar (RFC 5545)', () => {
  it('writes UTC times in the basic format', () => {
    expect(toIcsUtc(Date.parse('2026-10-01T18:00:00Z'))).toBe('20261001T180000Z');
    expect(toIcsUtc(Date.parse('2026-01-05T03:04:05Z'))).toBe('20260105T030405Z');
  });

  it('escapes backslash, semicolon, comma and newlines in text values', () => {
    expect(escapeIcsText('a\\b;c,d\ne')).toBe('a\\\\b\\;c\\,d\\ne');
  });

  it('folds lines at 75 octets without splitting a character', () => {
    const long = `DESCRIPTION:${'ç'.repeat(60)}`;
    const folded = foldIcsLine(long);
    for (const part of folded.split('\r\n')) expect(new TextEncoder().encode(part).length).toBeLessThanOrEqual(75);
    expect(folded.split('\r\n').map((p, i) => (i === 0 ? p : p.slice(1))).join('')).toBe(long);
    expect(foldIcsLine('SHORT:line')).toBe('SHORT:line');
  });

  it('builds a calendar with CRLF line ends and one event', () => {
    const text = buildIcs(event, Date.parse('2026-10-08T12:00:00Z'));
    expect(text.endsWith('\r\n')).toBe(true);
    expect(text.split('\r\n')[0]).toBe('BEGIN:VCALENDAR');
    expect(text).toContain('UID:bk_7Hq2xkP9@bellohub.app');
    expect(text).toContain('DTSTART:20261001T180000Z');
    expect(text).toContain('DTEND:20261001T193000Z');
    expect(text).toContain('SUMMARY;LANGUAGE=en:Brazilian Glow\\, with Maria Beauty');
    expect(text).toContain('LOCATION;LANGUAGE=en:São Paulo');
    expect(text.match(/BEGIN:VEVENT/g)).toHaveLength(1);
    expect(text).not.toMatch(/[^\r]\n/);
  });

  it('never puts the manage token in the UID', () => {
    expect(buildIcs(event, 0)).not.toContain('7Hq2xk@');
  });

  it('builds a Google Calendar link with the same event', () => {
    const url = new URL(googleCalendarUrl(event));
    expect(url.origin).toBe('https://calendar.google.com');
    expect(url.searchParams.get('action')).toBe('TEMPLATE');
    expect(url.searchParams.get('dates')).toBe('20261001T180000Z/20261001T193000Z');
    expect(url.searchParams.get('text')).toBe(event.summary);
  });
});

describe('what a calendar entry carries (D50)', () => {
  const booking = {
    bookingId: 'bk_7Hq2xkP9',
    startsAt: '2026-10-01T18:00:00.000Z',
    endsAt: '2026-10-01T19:30:00.000Z',
    serviceNames: ['Glow Facial'],
    professional: { displayName: 'Maria Beauty', city: 'São Paulo' },
  };
  const t = (key: string, params?: Record<string, string>): string => `${key}|${params?.['link'] ?? ''}`;

  it('carries the public booking page address and nothing else that is a link', () => {
    const entry = calendarEvent(booking, 'https://bellohub.app/maria', t, 'en');
    expect(entry.description).toBe('ics.page|https://bellohub.app/maria');
    const file = buildIcs(entry, 0);
    const url = googleCalendarUrl(entry);
    expect(file).toContain('https://bellohub.app/maria');
    expect(url).toContain(encodeURIComponent('https://bellohub.app/maria'));
    expect(file).not.toContain('/m/');
    expect(url).not.toContain('%2Fm%2F');
  });

  it('adds where she works: the address as LOCATION and its map link on a line of its own', () => {
    const place = {
      lines: ['Rua Augusta 1200', 'São Paulo 01304-001'],
      maps: { apple: 'https://maps.apple.com/?address=x', google: 'https://www.google.com/maps/search/?api=1&query=x' },
    };
    const entry = calendarEvent({ ...booking, place }, 'https://bellohub.app/maria', t, 'en');
    expect(entry.location).toBe('Rua Augusta 1200, São Paulo 01304-001');
    expect(entry.description).toBe('ics.page|https://bellohub.app/maria\nics.map|https://www.google.com/maps/search/?api=1&query=x');
    expect(calendarEvent(booking, 'https://bellohub.app/maria', t, 'en').location).toBe('São Paulo');
  });
});

// S11: the calendar entry in each of the fourteen localizations, built with the real locale files: the summary and
// the page line are translated (no key left), the file stays valid RFC 5545, and names are isolated only in Arabic.
describe('calendar entry in every localization', () => {
  const booking = {
    bookingId: 'bk_7Hq2xkP9',
    startsAt: '2026-10-01T18:00:00.000Z',
    endsAt: '2026-10-01T19:30:00.000Z',
    serviceNames: ['Limpeza de pele profunda', 'Hidratação'],
    professional: { displayName: 'Conceição Araújo', city: 'São Paulo' },
  };

  it.each(LOCALE_IDS)('%s', (id) => {
    const catalog = JSON.parse(readFileSync(new URL(`../../src/i18n/${id}.json`, import.meta.url), 'utf8')) as Record<string, string>;
    const t = makeTranslate(catalog, id);
    const entry = calendarEvent(booking, 'https://bellohub.app/maria', t, id);
    const file = buildIcs(entry, Date.parse('2026-10-08T12:00:00Z'));
    const unfolded = file.replace(/\r\n /g, '');

    expect(entry.summary).not.toMatch(/^ics\./);
    expect(entry.description).not.toMatch(/^ics\./);
    expect(entry.summary).toContain('Conceição Araújo');
    expect(unfolded).toContain('https://bellohub.app/maria');
    for (const line of file.split('\r\n')) expect(new TextEncoder().encode(line).length).toBeLessThanOrEqual(75);
    expect(entry.summary.includes('⁨')).toBe(id === 'ar');
  });
});
