// One error type for everything the server or the network can do wrong. It carries a code and nothing else:
// no body, no token, no personal data, so it is always safe to show, log or send to an error boundary.

import type { ApiErrorCode, ErrorContact } from './types';

export class ApiError extends Error {
  constructor(
    readonly code: ApiErrorCode,
    readonly status = 0,
    readonly retryAfterSeconds?: number,
    /** For an unknown or expired link: the professional to message. */
    readonly contact?: ErrorContact,
  ) {
    super(code);
    this.name = 'ApiError';
  }
}

const CODES: readonly ApiErrorCode[] = [
  'invalidInput', 'notFound', 'expired', 'rateLimited', 'appCheck', 'slotTaken', 'paused', 'codeInvalid',
  'codeExpired', 'tooManyAttempts', 'notAllowed', 'tooLarge', 'unavailable', 'network', 'timeout', 'server',
];

export function isApiErrorCode(value: unknown): value is ApiErrorCode {
  return typeof value === 'string' && (CODES as readonly string[]).includes(value);
}

/** The code for an HTTP status when the body does not name one. */
export function codeForStatus(status: number): ApiErrorCode {
  switch (status) {
    case 400:
    case 422:
      return 'invalidInput';
    case 401:
    case 403:
      return 'appCheck';
    case 404:
      return 'notFound';
    case 409:
      return 'slotTaken';
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
