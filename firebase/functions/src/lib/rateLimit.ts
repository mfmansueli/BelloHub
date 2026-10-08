import type { Deps } from '../app/Deps.js';
import type { RateLimit } from '../config/limits.js';
import { keyedHash } from './crypto.js';
import { AppError } from './errors.js';
import type { RateDoc } from './docs.js';
import { refs, ts } from './store.js';

/**
 * Fixed-window counter (docs/11 section 6). The subject (an IP hash, a phone, a token) goes into a keyed hash, so the
 * counter documents hold no personal data and cannot be linked back to a person without the pepper.
 * Throws RATE_LIMITED with `retryAfterSeconds` once the limit is passed. Documents expire with their window.
 */
export async function consumeRate(deps: Deps, scope: string, subject: string, rate: RateLimit): Promise<void> {
  const now = deps.now();
  const windowMs = rate.windowSeconds * 1000;
  const windowIndex = Math.floor(now / windowMs);
  const key = keyedHash(deps.pepper, 'rate', `${scope}|${subject}|${windowIndex}`).slice(0, 40);
  const ref = refs(deps.db).rate(key);
  const windowEnd = (windowIndex + 1) * windowMs;

  await deps.db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const count = snapshot.exists ? (snapshot.data() as RateDoc).count : 0;
    if (count >= rate.limit) {
      throw new AppError('RATE_LIMITED', { retryAfterSeconds: Math.max(1, Math.ceil((windowEnd - now) / 1000)) });
    }
    tx.set(ref, { count: count + 1, expiresAt: ts(windowEnd + 60_000) } satisfies RateDoc);
  });
}

/** Applies several limits in order; the first that is exceeded stops the call. */
export async function consumeRates(
  deps: Deps,
  limits: readonly { scope: string; subject: string; rate: RateLimit }[]
): Promise<void> {
  for (const { scope, subject, rate } of limits) {
    await consumeRate(deps, scope, subject, rate);
  }
}
