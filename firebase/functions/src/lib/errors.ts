// Errors the client may see. The code is the only thing that crosses the wire: stable, generic, free of personal data
// (docs/11 section 3, API.md section 3). Anything that is not an AppError becomes INTERNAL without its message.

export const ERROR_CODES = [
  'INVALID_ARGUMENT',
  'UNAUTHENTICATED',
  'APP_CHECK_REQUIRED',
  'FORBIDDEN',
  'NOT_FOUND',
  'TOKEN_EXPIRED',
  'RATE_LIMITED',
  'VERIFICATION_FAILED',
  'VERIFICATION_REQUIRED',
  'INVALID_CODE',
  'NOT_ALLOWED',
  'CONFIRMATION_REQUIRED',
  'BOOKING_NOT_ACTIVE',
  'SLUG_TAKEN',
  'KEY_MISMATCH',
  'PAYLOAD_TOO_LARGE',
  'CONFLICT',
  'NOT_CONFIGURED',
  'TRY_AGAIN',
  'INTERNAL'
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

/**
 * The Firebase callable status of each code and the HTTP status that status produces on the wire. A test checks the
 * HTTP column against the SDK's own mapping, and API.md's table against this one.
 */
export const ERROR_STATUS: Record<ErrorCode, { status: string; http: number }> = {
  INVALID_ARGUMENT: { status: 'invalid-argument', http: 400 },
  UNAUTHENTICATED: { status: 'unauthenticated', http: 401 },
  APP_CHECK_REQUIRED: { status: 'unauthenticated', http: 401 },
  FORBIDDEN: { status: 'permission-denied', http: 403 },
  NOT_FOUND: { status: 'not-found', http: 404 },
  TOKEN_EXPIRED: { status: 'not-found', http: 404 },
  RATE_LIMITED: { status: 'resource-exhausted', http: 429 },
  VERIFICATION_FAILED: { status: 'permission-denied', http: 403 },
  VERIFICATION_REQUIRED: { status: 'failed-precondition', http: 400 },
  INVALID_CODE: { status: 'invalid-argument', http: 400 },
  NOT_ALLOWED: { status: 'failed-precondition', http: 400 },
  CONFIRMATION_REQUIRED: { status: 'failed-precondition', http: 400 },
  BOOKING_NOT_ACTIVE: { status: 'failed-precondition', http: 400 },
  SLUG_TAKEN: { status: 'already-exists', http: 409 },
  KEY_MISMATCH: { status: 'failed-precondition', http: 400 },
  PAYLOAD_TOO_LARGE: { status: 'invalid-argument', http: 400 },
  CONFLICT: { status: 'already-exists', http: 409 },
  NOT_CONFIGURED: { status: 'unavailable', http: 503 },
  TRY_AGAIN: { status: 'unavailable', http: 503 },
  INTERNAL: { status: 'internal', http: 500 }
};

/** Details are structured and never hold personal data: ids, counts, seconds, field paths. */
export type ErrorDetails = Record<string, string | number | boolean | string[] | undefined>;

export class AppError extends Error {
  readonly code: ErrorCode;
  readonly details: ErrorDetails | undefined;

  constructor(code: ErrorCode, details?: ErrorDetails) {
    super(code);
    this.name = 'AppError';
    this.code = code;
    this.details = details;
  }
}

export function isAppError(value: unknown): value is AppError {
  return value instanceof AppError;
}
