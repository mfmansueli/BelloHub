import { describe, expect, it } from 'vitest';

import { buildIcs, escapeIcsText, foldIcsLine, googleCalendarUrl, toIcsUtc, type CalendarEvent } from '../../src/lib/ics';

const event: CalendarEvent = {
  uid: 'bk_7Hq2xkP9',
  startMs: Date.parse('2026-10-01T18:00:00Z'),
  endMs: Date.parse('2026-10-01T19:30:00Z'),
  summary: 'Brazilian Glow, with Maria Beauty',
  description: 'Change or cancel: https://bellohub.app/m/7Hq2xk\nFree changes until Wed, Sep 30 at 15:00.',
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
