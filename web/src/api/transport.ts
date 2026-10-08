// The only place that calls `fetch`. One function per HTTPS Cloud Function: GET with a query string for reads,
// POST with a JSON body for everything that changes state. Success is a 2xx with the response type as the body;
// failure is a non-2xx whose body is `{"error":{"code":"...","retryAfterSeconds":n}}` (the status is the fallback).
// If the real functions use another envelope (callable `{data}` / `{result}`), this file is the only thing to change.

import { ApiError, codeForStatus, isApiErrorCode } from './errors';
import type { ErrorContact } from './types';

export interface TransportOptions {
  readonly baseUrl: string;
  /** Returns an App Check token, or null when App Check is off. Never throws. */
  readonly appCheckToken: () => Promise<string | null>;
  readonly fetchImpl?: typeof fetch;
  readonly timeoutMs?: number;
}

export type Query = Readonly<Record<string, string | number | readonly string[] | undefined>>;

export interface Transport {
  get(name: string, query?: Query): Promise<unknown>;
  post(name: string, body: unknown): Promise<unknown>;
}

function queryString(query: Query): string {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value === undefined) continue;
    params.set(key, typeof value === 'object' ? value.join(',') : String(value));
  }
  const text = params.toString();
  return text === '' ? '' : `?${text}`;
}

export function createTransport(options: TransportOptions): Transport {
  const timeoutMs = options.timeoutMs ?? 15_000;

  async function request(name: string, init: RequestInit, search = ''): Promise<unknown> {
    const fetchImpl = options.fetchImpl ?? fetch;
    const controller = new AbortController();
    const timer = window.setTimeout(() => {
      controller.abort();
    }, timeoutMs);
    try {
      const token = await options.appCheckToken();
      const headers = new Headers(init.headers);
      headers.set('Accept', 'application/json');
      if (token !== null) headers.set('X-Firebase-AppCheck', token);
      let response: Response;
      try {
        response = await fetchImpl(`${options.baseUrl}/${name}${search}`, {
          ...init,
          headers,
          signal: controller.signal,
          credentials: 'omit',
          cache: 'no-store',
          referrerPolicy: 'no-referrer',
        });
      } catch (error) {
        throw new ApiError(controller.signal.aborted || (error instanceof DOMException && error.name === 'AbortError') ? 'timeout' : 'network');
      }
      let payload: unknown = null;
      try {
        payload = await response.json();
      } catch {
        payload = null;
      }
      if (!response.ok) throw toError(response.status, payload);
      return payload;
    } finally {
      window.clearTimeout(timer);
    }
  }

  return {
    get: (name, query = {}) => request(name, { method: 'GET' }, queryString(query)),
    post: (name, body) =>
      request(name, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }),
  };
}

function toError(status: number, payload: unknown): ApiError {
  if (typeof payload === 'object' && payload !== null) {
    const error = (payload as Record<string, unknown>)['error'];
    if (typeof error === 'object' && error !== null) {
      const { code, retryAfterSeconds, professional } = error as Record<string, unknown>;
      return new ApiError(
        isApiErrorCode(code) ? code : codeForStatus(status),
        status,
        typeof retryAfterSeconds === 'number' ? retryAfterSeconds : undefined,
        toContact(professional),
      );
    }
  }
  return new ApiError(codeForStatus(status), status);
}

function toContact(value: unknown): ErrorContact | undefined {
  if (typeof value !== 'object' || value === null) return undefined;
  const { displayName, firstName, whatsappE164 } = value as Record<string, unknown>;
  if (typeof displayName !== 'string' || typeof firstName !== 'string') return undefined;
  return { displayName, firstName, ...(typeof whatsappE164 === 'string' ? { whatsappE164 } : {}) };
}
