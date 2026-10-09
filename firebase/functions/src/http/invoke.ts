// The transport-independent core of every callable: access gate, strict input validation, the use case, error mapping
// and safe logging. `callable.ts` feeds it a Firebase request; tests feed it directly with an injected clock.

import type { ZodError } from 'zod';

import type { Deps } from '../app/Deps.js';
import type { AnyUseCase, CallContext } from '../app/UseCase.js';
import { AppError, isAppError } from '../lib/errors.js';

export interface CallInput {
  /** The request body's `data`, unvalidated. */
  data: unknown;
  /** The verified Firebase Auth uid, when the ID token was valid. */
  uid?: string | undefined;
  authPhone?: string | undefined;
  /** A valid App Check token came with the request. */
  appCheck: boolean;
  ipHash: string;
}

/** Field paths of a validation failure. Paths only: a value may be personal data and is never echoed. */
export function invalidFields(error: ZodError): string[] {
  const fields = new Set<string>();
  for (const issue of error.issues) {
    const keys = issue.code === 'unrecognized_keys' ? issue.keys : [undefined];
    for (const key of keys) {
      const path = [...issue.path, ...(key === undefined ? [] : [key])].map(String).join('.');
      fields.add((path || '(root)').slice(0, 80));
    }
  }
  return [...fields].slice(0, 10);
}

/** Runs one use case. Throws only AppError: anything else is logged by code and turned into INTERNAL. */
export async function invokeUseCase(deps: Deps, useCase: AnyUseCase, call: CallInput): Promise<unknown> {
  const started = deps.now();
  try {
    if (useCase.access === 'owner' && !call.uid) throw new AppError('UNAUTHENTICATED');
    if (deps.settings.enforceAppCheck && !call.appCheck) throw new AppError('APP_CHECK_REQUIRED');

    const parsed = useCase.input.safeParse(call.data);
    if (!parsed.success) throw new AppError('INVALID_ARGUMENT', { fields: invalidFields(parsed.error) });

    const ctx: CallContext = {
      ...(call.uid ? { uid: call.uid } : {}),
      ...(call.authPhone ? { authPhone: call.authPhone } : {}),
      appCheck: call.appCheck,
      ipHash: call.ipHash
    };
    const output: unknown = await useCase.handle(deps, parsed.data, ctx);
    if (deps.settings.validateOutputs) {
      // Tests and the emulator prove every response matches the schema that API.md is generated from.
      const checked = useCase.output.safeParse(output);
      if (!checked.success) {
        deps.log.error('output.invalid', { function: useCase.name, count: checked.error.issues.length });
        throw new AppError('INTERNAL');
      }
    }
    deps.log.info('call.ok', { function: useCase.name, durationMs: deps.now() - started });
    return output;
  } catch (error) {
    if (isAppError(error)) {
      deps.log.info('call.rejected', { function: useCase.name, code: error.code, durationMs: deps.now() - started });
      throw error;
    }
    // Never the message: SDK errors can quote documents. The numeric or short code is enough to find the cause.
    const rawCode = (error as { code?: unknown }).code;
    deps.log.error('call.failed', {
      function: useCase.name,
      reason: typeof rawCode === 'string' || typeof rawCode === 'number' ? String(rawCode) : (error as Error).name,
      durationMs: deps.now() - started
    });
    throw new AppError('INTERNAL');
  }
}
