import type { Deps } from '../../app/Deps.js';
import { C } from '../../lib/docs.js';
import { ts } from '../../lib/store.js';
import { sweep } from './sweep.js';

export interface TemporaryCounts {
  holds: number;
  codes: number;
  rows: number;
  waitlist: number;
  portals: number;
}

/**
 * Everything with a short life: soft holds (5 minutes), email codes and proofs, trusted devices (90 days), rate counters, idempotency keys, audit
 * events past 400 days, waitlist entries 7 days after their last day, portals revoked or idle for 180 days.
 * Each has a Firestore TTL policy too; this is the guarantee that does not depend on it.
 */
export async function expireTemporary(deps: Deps, now: number): Promise<TemporaryCounts> {
  const cutoff = ts(now);
  const expired = (collection: string, field = 'expiresAt') => deps.db.collection(collection).where(field, '<=', cutoff);
  return {
    holds: await sweep(deps, expired(C.holds)),
    codes:
      (await sweep(deps, expired(C.emailCodes))) +
      (await sweep(deps, expired(C.emailProofs))) +
      (await sweep(deps, expired(C.trustedDevices))),
    rows:
      (await sweep(deps, expired(C.rate))) +
      (await sweep(deps, expired(C.idempotency))) +
      (await sweep(deps, expired(C.audit))),
    waitlist: await sweep(deps, expired(C.waitlist)),
    // A revoked portal is removed at once, not left until its 180 days are over.
    portals: (await sweep(deps, expired(C.portal))) + (await sweep(deps, expired(C.portal, 'revokedAt')))
  };
}
