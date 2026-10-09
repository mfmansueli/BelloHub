import type { Deps } from '../../app/Deps.js';
import { C } from '../../lib/docs.js';
import { ts } from '../../lib/store.js';
import { sweep } from './sweep.js';

/** D30: bookings leave the server 7 days after the visit (`purgeAt`), and so do the requests tied to them. */
export async function purgeBookings(deps: Deps, now: number): Promise<{ bookings: number; requests: number }> {
  const cutoff = ts(now);
  const bookings = await sweep(deps, deps.db.collection(C.bookings).where('purgeAt', '<=', cutoff));
  const requests = await sweep(deps, deps.db.collection(C.rescheduleRequests).where('purgeAt', '<=', cutoff));
  return { bookings, requests };
}
