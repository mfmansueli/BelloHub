import { HttpsError, onCall } from 'firebase-functions/v2/https';
import type { CallableRequest, CallableFunction } from 'firebase-functions/v2/https';

import { createDeps } from '../app/createDeps.js';
import type { Deps } from '../app/Deps.js';
import type { AnyUseCase } from '../app/UseCase.js';
import { FUNCTIONS_REGION } from '../config/region.js';
import { PHONE_HASH_PEPPER } from '../config/params.js';
import { clientIpFrom } from '../lib/clientIp.js';
import { keyedHash } from '../lib/crypto.js';
import { ERROR_STATUS, isAppError } from '../lib/errors.js';
import type { ErrorCode, ErrorDetails } from '../lib/errors.js';
import { invokeUseCase } from './invoke.js';

/**
 * Hosting domains of the web app and the previews of OUR projects (site ids start with `bellohub` or `bello-hub`, preview
 * channels append `--<channel>-<hash>`); not every Firebase site on earth. The emulator accepts any origin.
 */
export const ALLOWED_ORIGINS: (string | RegExp)[] = [
  /^https:\/\/([a-z0-9-]+\.)*bellohub\.app$/,
  /^https:\/\/bello-?hub[a-z0-9-]*\.web\.app$/,
  /^https:\/\/bello-?hub[a-z0-9-]*\.firebaseapp\.com$/
];

export function toHttpsError(error: unknown): HttpsError {
  if (isAppError(error)) {
    const mapped = ERROR_STATUS[error.code];
    return new HttpsError(mapped.status as ConstructorParameters<typeof HttpsError>[0], error.code, error.details);
  }
  return new HttpsError('internal', 'INTERNAL');
}

/** The caller's IP, hashed with the pepper: used for rate limits and never stored or logged in the clear. */
export function ipHashOf(deps: Deps, request: CallableRequest): string {
  const forwarded = request.rawRequest.headers['x-forwarded-for'];
  const ip = clientIpFrom(
    Array.isArray(forwarded) ? forwarded.join(',') : forwarded,
    request.rawRequest.socket.remoteAddress,
    deps.settings.trustedProxyHops
  );
  return keyedHash(deps.pepper, 'ip', ip);
}

/**
 * Exposes a use case as a callable function (Firebase protocol over HTTPS; Auth and App Check tokens are verified by the
 * platform). App Check ENFORCEMENT is decided at run time by `invokeUseCase` from the `ENFORCE_APP_CHECK` parameter:
 * the SDK's own `enforceAppCheck` option reads a parameter while the functions are being defined, which warns on every
 * function and cannot be changed without a redeploy.
 */
export function defineCallable(useCase: AnyUseCase, options: { timeoutSeconds?: number; memory?: '256MiB' | '512MiB' } = {}): CallableFunction<unknown, Promise<unknown>> {
  return onCall(
    {
      region: FUNCTIONS_REGION,
      cors: ALLOWED_ORIGINS,
      secrets: [PHONE_HASH_PEPPER],
      memory: options.memory ?? '256MiB',
      timeoutSeconds: options.timeoutSeconds ?? 60,
      maxInstances: 20
    },
    async (request) => {
      const deps = createDeps();
      try {
        return await invokeUseCase(deps, useCase, {
          data: request.data,
          uid: request.auth?.uid,
          authPhone: typeof request.auth?.token.phone_number === 'string' ? request.auth.token.phone_number : undefined,
          appCheck: request.app !== undefined,
          ipHash: ipHashOf(deps, request)
        });
      } catch (error) {
        throw toHttpsError(error);
      }
    }
  );
}

export type { ErrorCode, ErrorDetails };
