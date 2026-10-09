// One error type for everything the server or the network can do wrong. It carries a code and nothing else:
// no body, no token, no personal data, so it is always safe to show, log or send to an error boundary.

import type { ApiErrorCode } from './types';

export class ApiError extends Error {
  constructor(
    readonly code: ApiErrorCode,
    readonly status = 0,
    readonly retryAfterSeconds?: number,
  ) {
    super(code);
    this.name = 'ApiError';
  }
}

/**
 * The server's stable codes (API.md section 3, `error.message`) mapped onto the page's vocabulary. The page branches
 * on the code, never on the HTTP status (the callable protocol picks the status).
 */
const SERVER_CODES: Readonly<Record<string, ApiErrorCode>> = {
  INVALID_ARGUMENT: 'invalidInput',
  UNAUTHENTICATED: 'appCheck',
  APP_CHECK_REQUIRED: 'appCheck',
  FORBIDDEN: 'notAllowed',
  NOT_FOUND: 'notFound',
  TOKEN_EXPIRED: 'expired',
  RATE_LIMITED: 'rateLimited',
  // The proof is missing, wrong, used, expired or for another contact: she needs a new code.
  VERIFICATION_FAILED: 'codeExpired',
  INVALID_CODE: 'codeInvalid',
  NOT_ALLOWED: 'notAllowed',
  // The page sends `acceptLateWarning` whenever its view says the cancellation is late; this only happens when the
  // free window closed between the load and the tap, so "not available any more" is the honest message.
  CONFIRMATION_REQUIRED: 'notAllowed',
  BOOKING_NOT_ACTIVE: 'notAllowed',
  SLUG_TAKEN: 'server',
  // A rotated inbox key: the sealed pages reload their context on this (never a silent retry with the old key).
  KEY_MISMATCH: 'invalidInput',
  PAYLOAD_TOO_LARGE: 'tooLarge',
  CONFLICT: 'server',
  NOT_CONFIGURED: 'unavailable',
  TRY_AGAIN: 'unavailable',
  INTERNAL: 'server',
};

export function codeForServer(message: unknown): ApiErrorCode | undefined {
  return typeof message === 'string' ? SERVER_CODES[message] : undefined;
}

/** The code for an HTTP status when the body does not name one. */
export function codeForStatus(status: number): ApiErrorCode {
  switch (status) {
    case 400:
    case 422:
      return 'invalidInput';
    case 401:
      return 'appCheck';
    case 403:
      return 'notAllowed';
    case 404:
      return 'notFound';
    case 409:
      return 'server';
    case 410:
      return 'expired';
    case 413:
      return 'tooLarge';
    case 429:
      return 'rateLimited';
    case 503:
      return 'unavailable';
    default:
      return 'server';
  }
}

export function asApiError(error: unknown): ApiError {
  if (error instanceof ApiError) return error;
  return new ApiError('network');
}
