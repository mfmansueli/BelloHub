// The only way the server writes a log line (docs/11 section 9, docs/06 section 8). Logs carry ids, kinds, sizes,
// durations and counts, never a name, phone, email, token, code or envelope.
//
// Safety is structural, not a convention: the field NAMES are a closed list, and each value must have the shape of
// an id, a short label or a number. A value that does not (a space, an "@", a long string) is replaced, so a careless
// `log.info('x', { code: someEmail })` cannot leak. Free text has no field at all.

export type Severity = 'DEBUG' | 'INFO' | 'WARNING' | 'ERROR';

type LogValue = string | number | boolean;

/** The closed list of field names. Add a name here only if it can never hold personal data. */
const ID_FIELDS = ['uid', 'ownerUid', 'bookingId', 'itemId', 'requestId', 'waitlistId', 'holdId', 'accountId', 'scope'] as const;
const LABEL_FIELDS = ['kind', 'status', 'decision', 'code', 'function', 'reason', 'phase', 'job', 'platform', 'suite', 'provider', 'template'] as const;
const NUMBER_FIELDS = [
  'count',
  'sizeBytes',
  'durationMs',
  'attempt',
  'deleted',
  'expired',
  'bookings',
  'holds',
  'envelopes',
  'codes',
  'portals',
  'waitlist',
  'requests',
  'rows',
  'sent',
  'failed',
  'registrations',
  'httpStatus'
] as const;

export type LogFields = Partial<Record<(typeof ID_FIELDS)[number] | (typeof LABEL_FIELDS)[number], string>> &
  Partial<Record<(typeof NUMBER_FIELDS)[number], number>> & { ok?: boolean };

const idFields = new Set<string>(ID_FIELDS);
const labelFields = new Set<string>(LABEL_FIELDS);
const numberFields = new Set<string>(NUMBER_FIELDS);

const ID_SHAPE = /^[A-Za-z0-9_.:-]{1,64}$/;
const LABEL_SHAPE = /^[A-Za-z0-9_.:-]{1,48}$/;
// Long tokens are ids too: the shape alone cannot tell a Firestore id from a secret, so secrets must simply never be
// passed here. These patterns catch the accidents that can be recognized.
const LOOKS_LIKE_JWT = /^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\./;
const LOOKS_LIKE_PHONE = /^\+?\d{7,15}$/;

export interface LogEntry {
  severity: Severity;
  event: string;
  fields: Record<string, LogValue>;
}

export interface LogSink {
  write(entry: LogEntry): void;
}

export interface Logger {
  debug(event: string, fields?: LogFields): void;
  info(event: string, fields?: LogFields): void;
  warn(event: string, fields?: LogFields): void;
  error(event: string, fields?: LogFields): void;
}

function scrubValue(key: string, value: unknown): LogValue | undefined {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return Number.isFinite(value) && numberFields.has(key) ? value : undefined;
  if (typeof value !== 'string') return undefined;
  if (LOOKS_LIKE_JWT.test(value) || LOOKS_LIKE_PHONE.test(value)) return '[redacted]';
  if (idFields.has(key)) return ID_SHAPE.test(value) ? value : '[redacted]';
  if (labelFields.has(key)) return LABEL_SHAPE.test(value) ? value : '[redacted]';
  return undefined;
}

export function scrubFields(fields: LogFields | undefined): Record<string, LogValue> {
  const result: Record<string, LogValue> = {};
  if (!fields) return result;
  for (const [key, value] of Object.entries(fields)) {
    if (key === 'ok') {
      if (typeof value === 'boolean') result[key] = value;
      continue;
    }
    if (!idFields.has(key) && !labelFields.has(key) && !numberFields.has(key)) {
      result.dropped = 'unknown-field';
      continue;
    }
    const scrubbed = scrubValue(key, value);
    if (scrubbed !== undefined) result[key] = scrubbed;
  }
  return result;
}

const EVENT_SHAPE = /^[A-Za-z0-9_.:-]{1,60}$/;

export function createLogger(sink: LogSink): Logger {
  const emit = (severity: Severity, event: string, fields?: LogFields): void => {
    sink.write({
      severity,
      event: EVENT_SHAPE.test(event) ? event : 'invalid-event',
      fields: scrubFields(fields)
    });
  };
  return {
    debug: (event, fields) => {
      emit('DEBUG', event, fields);
    },
    info: (event, fields) => {
      emit('INFO', event, fields);
    },
    warn: (event, fields) => {
      emit('WARNING', event, fields);
    },
    error: (event, fields) => {
      emit('ERROR', event, fields);
    }
  };
}

/** A sink that keeps entries in memory (tests assert on them). */
export class MemoryLogSink implements LogSink {
  readonly entries: LogEntry[] = [];
  write(entry: LogEntry): void {
    this.entries.push(entry);
  }
}
