import { write } from 'firebase-functions/logger';

import type { LogEntry, LogSink } from './log.js';

/** Structured Cloud Logging entries: severity, an event name and the scrubbed fields. Nothing else reaches the log. */
export class CloudLogSink implements LogSink {
  write(entry: LogEntry): void {
    write({ severity: entry.severity, message: entry.event, ...entry.fields });
  }
}
