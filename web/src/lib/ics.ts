// "Add to calendar": an iCalendar file (RFC 5545) and a Google Calendar link, built in the browser from what
// the page already shows. No request is made; the file is a Blob the browser saves.

export interface CalendarEvent {
  /** Opaque, stable id of the booking (never the manage token). */
  readonly uid: string;
  readonly startMs: number;
  readonly endMs: number;
  readonly summary: string;
  readonly description: string;
  readonly location?: string;
  /** Language of the text, so calendar apps hyphenate and speak it right. */
  readonly language?: string;
}

export function toIcsUtc(ms: number): string {
  const d = new Date(ms);
  const pad = (n: number, len = 2): string => String(n).padStart(len, '0');
  return (
    `${pad(d.getUTCFullYear(), 4)}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}` +
    `T${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}Z`
  );
}

/** Escapes a TEXT value (RFC 5545 section 3.3.11). */
export function escapeIcsText(text: string): string {
  return text
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\r\n|\r|\n/g, '\\n');
}

const encoder = new TextEncoder();

/** Folds a content line at 75 octets without splitting a UTF-8 character (RFC 5545 section 3.1). */
export function foldIcsLine(line: string): string {
  if (encoder.encode(line).length <= 75) return line;
  const parts: string[] = [];
  let current = '';
  let currentBytes = 0;
  let limit = 75;
  for (const char of line) {
    const bytes = encoder.encode(char).length;
    if (currentBytes + bytes > limit) {
      parts.push(current);
      current = ' ';
      currentBytes = 1;
      limit = 75;
    }
    current += char;
    currentBytes += bytes;
  }
  parts.push(current);
  return parts.join('\r\n');
}

export function buildIcs(event: CalendarEvent, nowMs: number): string {
  const language = event.language === undefined ? '' : `;LANGUAGE=${event.language}`;
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Bello Hub//Booking//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${event.uid}@bellohub.app`,
    `DTSTAMP:${toIcsUtc(nowMs)}`,
    `DTSTART:${toIcsUtc(event.startMs)}`,
    `DTEND:${toIcsUtc(event.endMs)}`,
    `SUMMARY${language}:${escapeIcsText(event.summary)}`,
    `DESCRIPTION${language}:${escapeIcsText(event.description)}`,
    ...(event.location === undefined ? [] : [`LOCATION${language}:${escapeIcsText(event.location)}`]),
    'STATUS:CONFIRMED',
    'TRANSP:OPAQUE',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return `${lines.map(foldIcsLine).join('\r\n')}\r\n`;
}

/** A link that opens Google Calendar with the event filled in (the client taps it; no request from the page). */
export function googleCalendarUrl(event: CalendarEvent): string {
  const params = new URLSearchParams({
    action: 'TEMPLATE',
    text: event.summary,
    dates: `${toIcsUtc(event.startMs)}/${toIcsUtc(event.endMs)}`,
    details: event.description,
  });
  if (event.location !== undefined) params.set('location', event.location);
  return `https://calendar.google.com/calendar/render?${params.toString()}`;
}
