import { FieldValue } from 'firebase-admin/firestore';

import type { Deps } from '../../app/Deps.js';
import { CLEANUP_BATCH } from '../../config/limits.js';
import { bumpCalendarLock, readCalendarLock } from '../../lib/calendar.js';
import type { BookingDoc } from '../../lib/docs.js';
import { C } from '../../lib/docs.js';
import { dataOf, msOpt, ts } from '../../lib/store.js';
import { runTransaction } from '../../lib/tx.js';

/**
 * Releases unverified requests nobody answered (verify-fallback item 1): 24 hours after they were made (or at the visit's
 * start) a WhatsApp-confirmed request that is still waiting becomes `declined` with `expiredAt`, and its time is free
 * again. The client is not e-mailed (her address was never proven). A request she answered keeps its `pendingExpiresAt`
 * only until this step sees it, which clears the field so the query stays small. Single-field query, no index needed.
 */
export async function expireRequests(deps: Deps, now: number): Promise<number> {
  let expired = 0;
  for (;;) {
    const page = await deps.db.collection(C.bookings).where('pendingExpiresAt', '<=', ts(now)).limit(CLEANUP_BATCH).get();
    if (page.empty) return expired;
    for (const snapshot of page.docs) {
      const released = await runTransaction(deps.db, async (tx) => {
        const booking = dataOf<BookingDoc>(await tx.get(snapshot.ref));
        if (!booking) return false;
        const due = (msOpt(booking.pendingExpiresAt) ?? Infinity) <= now;
        if (booking.status !== 'pendingApproval' || !due) {
          tx.update(snapshot.ref, { pendingExpiresAt: FieldValue.delete() });
          return false;
        }
        await readCalendarLock(tx, deps.db, booking.ownerUid);
        tx.update(snapshot.ref, {
          status: 'declined',
          pendingReason: FieldValue.delete(),
          pendingExpiresAt: FieldValue.delete(),
          expiredAt: ts(now),
          updatedAt: ts(now)
        });
        bumpCalendarLock(tx, deps.db, booking.ownerUid);
        return true;
      });
      if (released) {
        expired += 1;
        deps.log.info('request.expired', { bookingId: snapshot.id, ownerUid: (snapshot.data() as BookingDoc).ownerUid });
      }
    }
    if (page.size < CLEANUP_BATCH) return expired;
  }
}

