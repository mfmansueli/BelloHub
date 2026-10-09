// The only place that calls `fetch`. Every function is a Firebase callable spoken by hand (API.md section 1, "Web"):
//
//   POST <base>/<name>      { "data": <request> }        -> 200 { "result": <response> }
//                                                        -> 4xx/5xx { "error": { "status", "message": CODE, "details"? } }
//
// Reads are POSTs too, so a token is never in a URL (docs/06 section 5). `error.message` is a stable machine code,
// never prose; `details` never holds personal data (only `retryAfterSeconds`, `fields`, `action`, `maxBytes`).

import { ApiError, codeForServer, codeForStatus } from './errors';

export interface TransportOptions {
  readonly baseUrl: string;
  /** Returns an App Check token, or null when App Check is off. Never throws. */
  readonly appCheckToken: () => Promise<string | null>;
  readonly fetchImpl?: typeof fetch;
  readonly timeoutMs?: number;
}

export interface Transport {
  /** Calls one function with its request object and returns the `result` object. */
  call(name: string, data: unknown): Promise<unknown>;
}

export function createTransport(options: TransportOptions): Transport {
  const timeoutMs = options.timeoutMs ?? 15_000;

  async function call(name: string, data: unknown): Promise<unknown> {
    const fetchImpl = options.fetchImpl ?? fetch;
    const controller = new AbortController();
    const timer = setTimeout(() => {
      controller.abort();
    }, timeoutMs);
    try {
      const token = await options.appCheckToken();
      const headers = new Headers({ Accept: 'application/json', 'Content-Type': 'application/json' });
      if (token !== null) headers.set('X-Firebase-AppCheck', token);
      let response: Response;
      try {
        response = await fetchImpl(`${options.baseUrl}/${name}`, {
          method: 'POST',
          headers,
          body: JSON.stringify({ data }),
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
      return unwrap(payload);
    } finally {
      clearTimeout(timer);
    }
  }

  return { call };
}

/** A 2xx whose body is not `{ result }` is a server fault, not a success. */
function unwrap(payload: unknown): unknown {
  if (typeof payload !== 'object' || payload === null || !('result' in payload)) throw new ApiError('server', 200);
  return payload.result;
}

export function toError(status: number, payload: unknown): ApiError {
  if (typeof payload === 'object' && payload !== null) {
    const error = (payload as Record<string, unknown>)['error'];
    if (typeof error === 'object' && error !== null) {
      const { message, details } = error as Record<string, unknown>;
      const retryAfter = typeof details === 'object' && details !== null ? (details as Record<string, unknown>)['retryAfterSeconds'] : undefined;
      return new ApiError(codeForServer(message) ?? codeForStatus(status), status, typeof retryAfter === 'number' ? retryAfter : undefined);
    }
  }
  return new ApiError(codeForStatus(status), status);
}
