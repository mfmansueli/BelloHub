import type { Deps } from '../app/Deps.js';
import { expireEnvelopes } from './steps/expireEnvelopes.js';
import { expireRequests } from './steps/expireRequests.js';
import { expireTemporary } from './steps/expireTemporary.js';
import { finishDeletions } from './steps/finishDeletions.js';
import { pruneKeyrings } from './steps/pruneKeyrings.js';
import { purgeBookings } from './steps/purgeBookings.js';
import { reconcileBlobs } from './steps/reconcileBlobs.js';

export interface CleanupReport {
  bookings: number;
  requests: number;
  /** Unverified booking requests released unanswered after 24 hours (verify-fallback). */
  expiredRequests: number;
  envelopes: number;
  holds: number;
  codes: number;
  rows: number;
  waitlist: number;
  portals: number;
  blobs: number;
  accounts: number;
  /** Key rings that lost retired keys nobody can need any more (D51). */
  keyrings: number;
}

/**
 * The retention jobs (D30, docs/11 section 3), one pass. `now` is a parameter so tests can run it at any instant with
 * a fixed clock; the scheduled function passes the real time. Every step is idempotent and bounded.
 */
export async function runCleanup(deps: Deps, now: number = deps.now()): Promise<CleanupReport> {
  const expiredRequests = await expireRequests(deps, now);
  const { bookings, requests } = await purgeBookings(deps, now);
  const envelopes = await expireEnvelopes(deps, now);
  const temporary = await expireTemporary(deps, now);
  const blobs = await reconcileBlobs(deps);
  const accounts = await finishDeletions(deps);
  const keyrings = await pruneKeyrings(deps, now);
  const report: CleanupReport = { bookings, requests, expiredRequests, envelopes, ...temporary, blobs, accounts, keyrings };
  deps.log.info('cleanup.done', {
    job: 'cleanup',
    bookings,
    requests,
    expired: expiredRequests,
    envelopes,
    holds: temporary.holds,
    codes: temporary.codes,
    rows: temporary.rows,
    waitlist: temporary.waitlist,
    portals: temporary.portals
  });
  return report;
}
