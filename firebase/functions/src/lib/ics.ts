// The calendar file a client adds to her phone (docs/10 section 3). RFC 5545: CRLF lines folded at 75 octets, text
// escaped, times in UTC (so a daylight-saving change can never move the event). Booking facts only: the service, the
// professional's name, where she works (when the client may see it) and her public booking page: D50, never the
// manage link, so a shared calendar cannot hand the booking to someone else. No health information.

import type { LocaleId } from '../contracts/common.js';

export interface IcsInput {
  bookingId: string;
  serviceName: string;
  professionalName: string;
  city?: string | undefined;
  /** Her address on one line, when this client may see it; it wins over the city. */
  address?: string | undefined;
  /** A map link for the address, added to the description. */
  mapUrl?: string | undefined;
  startsAt: number;
  endsAt: number;
  /** A booking still waiting for the professional is TENTATIVE. */
  tentative: boolean;
  /** Her public booking page (D50). */
  link: string;
  /** The file's creation time (also its sequence), epoch ms. */
  now: number;
  locale: LocaleId;
}

const FSI = String.fromCharCode(0x2068);
const PDI = String.fromCharCode(0x2069);

function utc(ms: number): string {
  return new Date(ms).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
}

export function escapeIcsText(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r\n|\r|\n/g, '\\n');
}

/** Folds a content line to at most 75 octets per physical line, never splitting a UTF-8 character. */
export function foldLine(line: string): string[] {
  const encoder = new TextEncoder();
  if (encoder.encode(line).length <= 75) return [line];
  const lines: string[] = [];
  let current = '';
  let currentBytes = 0;
  // The first line may hold 75 octets, continuation lines 74 (they start with one space).
  let limit = 75;
  for (const character of line) {
    const size = encoder.encode(character).length;
    if (currentBytes + size > limit) {
      lines.push(lines.length === 0 ? current : ` ${current}`);
      current = '';
      currentBytes = 0;
      limit = 74;
    }
    current += character;
    currentBytes += size;
  }
  lines.push(lines.length === 0 ? current : ` ${current}`);
  return lines;
}

export function buildIcs(input: IcsInput): string {
  const isolate = (value: string): string => (input.locale === 'ar' ? `${FSI}${value}${PDI}` : value);
  const summary = `${isolate(input.serviceName)} - ${isolate(input.professionalName)}`;
  const description = [summary, input.link, ...(input.mapUrl ? [input.mapUrl] : [])].join('\n');
  const place = input.address ?? input.city;
  const content: string[] = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Bello Hub//Booking//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:booking-${input.bookingId}@bellohub.app`,
    `DTSTAMP:${utc(input.now)}`,
    `DTSTART:${utc(input.startsAt)}`,
    `DTEND:${utc(input.endsAt)}`,
    `SUMMARY:${escapeIcsText(summary)}`,
    `DESCRIPTION:${escapeIcsText(description)}`,
    ...(place ? [`LOCATION:${escapeIcsText(isolate(place))}`] : []),
    `URL:${input.link}`,
    `STATUS:${input.tentative ? 'TENTATIVE' : 'CONFIRMED'}`,
    'TRANSP:OPAQUE',
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    `DESCRIPTION:${escapeIcsText(summary)}`,
    'TRIGGER:-PT24H',
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR'
  ];
  return `${content.flatMap(foldLine).join('\r\n')}\r\n`;
}
