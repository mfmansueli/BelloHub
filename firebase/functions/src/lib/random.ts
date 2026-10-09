import { randomBytes, randomInt, randomUUID } from 'node:crypto';

import { base64url } from './crypto.js';

/** Randomness behind an interface so tests can pin it. Production uses the OS generator. */
export interface Random {
  bytes(length: number): Buffer;
  uuid(): string;
  /** A 128-bit secret as 22 base64url characters (manage tokens, proofs, hold keys). */
  token(): string;
  /** Six decimal digits, uniformly distributed, with leading zeros kept. */
  code6(): string;
}

export const systemRandom: Random = {
  bytes: (length) => randomBytes(length),
  uuid: () => randomUUID(),
  token: () => base64url(randomBytes(16)),
  code6: () => String(randomInt(0, 1_000_000)).padStart(6, '0')
};
