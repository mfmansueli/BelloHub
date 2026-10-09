import type { z } from 'zod';

import type { Deps } from './Deps.js';

export type Access = 'public' | 'token' | 'owner';

/** What the transport knows about the caller, handed to the use case. */
export interface CallContext {
  /** The signed-in professional (owner functions). */
  uid?: string;
  /** The phone number on the professional's ID token, when it has one. */
  authPhone?: string;
  /** A valid App Check token came with the request. */
  appCheck: boolean;
  /** Keyed hash of the caller's IP: used for rate limits only, never stored or logged. */
  ipHash: string;
}

export interface UseCase<I extends z.ZodType, O extends z.ZodType> {
  name: string;
  access: Access;
  input: I;
  output: O;
  handle(deps: Deps, input: z.output<I>, ctx: CallContext): Promise<z.output<O>>;
}

/** Keeps the generic parameters inferred: `defineUseCase({ name, access, ...schemas, handle })`. */
export function defineUseCase<I extends z.ZodType, O extends z.ZodType>(useCase: UseCase<I, O>): UseCase<I, O> {
  return useCase;
}

/** Any use case, for registries that do not care about its schemas. */
export type AnyUseCase = UseCase<z.ZodType, z.ZodType>;

export function ownerUid(ctx: CallContext): string {
  if (!ctx.uid) throw new Error('owner use case called without a uid');
  return ctx.uid;
}
