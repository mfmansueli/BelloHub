import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { instantMs, iso } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import { sendBookingEmail } from '../lib/bookingEmails.js';
import { bumpCalendarLock, readCalendarLock } from '../lib/calendar.js';
import type { PublicProfileDoc } from '../lib/docs.js';
import { ACTIVE_BOOKING_STATUSES } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { loadOwnedBooking } from '../lib/ownedBooking.js';
import { consumeRate } from '../lib/rateLimit.js';
import { purgeAtFor } from '../lib/rules.js';
import { dataOf, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';
import { FieldValue } from 'firebase-admin/firestore';

/**
 * She moves a booking that came from the link. Her own rules are not checked (she may work outside her hours when she
 * chooses to); the client is told by email. The move updates the retention date with the visit.
 */
export const moveBookingByOwner = defineUseCase({
  name: 'moveBookingByOwner',
  access: 'owner',
  ...contract.moveBookingByOwner,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    const now = deps.now();
    const startsAt = instantMs(input.startsAt);

    const result = await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const booking = await loadOwnedBooking(reader, deps.db, uid, input.bookingId);
      if (!ACTIVE_BOOKING_STATUSES.includes(booking.data.status)) {
        throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
      }
      const profile = dataOf<PublicProfileDoc>(await reader.doc(refs(deps.db).profile(booking.data.slug)));
      await readCalendarLock(tx, deps.db, uid);

      const endsAt = startsAt + booking.data.durationMinutes * 60_000;
      tx.update(booking.ref, {
        startsAt: ts(startsAt),
        endsAt: ts(endsAt),
        purgeAt: ts(purgeAtFor(endsAt)),
        clientConfirmedAt: FieldValue.delete(),
        lateByMinutes: FieldValue.delete(),
        lateReportedAt: FieldValue.delete(),
        reminderSentAt: FieldValue.delete(),
        updatedAt: ts(now)
      });
      bumpCalendarLock(tx, deps.db, uid);
      return { booking: { ...booking.data, startsAt: ts(startsAt), endsAt: ts(endsAt) }, name: profile?.displayName ?? '', endsAt };
    });

    await sendBookingEmail(deps, { template: 'bookingMoved', booking: result.booking, professionalName: result.name, linkToPage: true });
    return { startsAt: iso(startsAt), endsAt: iso(result.endsAt) };
  }
});
