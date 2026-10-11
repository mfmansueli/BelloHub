import { FieldValue } from 'firebase-admin/firestore';

import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import { tokenHash, withNewTokenHash } from '../lib/bookingAccess.js';
import { sendBookingEmail } from '../lib/bookingEmails.js';
import { bookingOffer, bumpCalendarLock, checkSlot, loadCalendar, readCalendarLock } from '../lib/calendar.js';
import type { BookingDoc, PublicProfileDoc, RescheduleRequestDoc } from '../lib/docs.js';
import { ACTIVE_BOOKING_STATUSES } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { loadOwnedBooking } from '../lib/ownedBooking.js';
import { consumeRate } from '../lib/rateLimit.js';
import { purgeAtFor } from '../lib/rules.js';
import { dataOf, ms, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * Accept moves the booking to the requested time if it is still free by her rules (otherwise `slotTaken` and the request
 * stays open for her to decline or to use `moveBookingByOwner`). Decline leaves the booking where it was. An accepted
 * move is e-mailed with one more manage token, so the e-mail carries her exact link (the same five-link cap).
 */
export const respondRescheduleRequest = defineUseCase({
  name: 'respondRescheduleRequest',
  access: 'owner',
  ...contract.respondRescheduleRequest,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    const r = refs(deps.db);
    const now = deps.now();
    const manageToken = deps.random.token();

    const outcome = await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const requestRef = r.rescheduleRequest(input.requestId);
      const request = dataOf<RescheduleRequestDoc>(await reader.doc(requestRef));
      if (request?.ownerUid !== uid) throw new AppError('NOT_FOUND');
      if (request.status !== 'pending') throw new AppError('BOOKING_NOT_ACTIVE', { status: request.status });
      const booking = await loadOwnedBooking(reader, deps.db, uid, request.bookingId);
      if (!ACTIVE_BOOKING_STATUSES.includes(booking.data.status)) {
        throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
      }

      if (input.decision === 'decline') {
        tx.update(requestRef, { status: 'declined', respondedAt: ts(now) });
        return { status: 'declined' as const };
      }

      const calendar = await loadCalendar(reader, deps.db, booking.data.slug);
      if (!calendar) throw new AppError('NOT_FOUND');
      const profile = dataOf<PublicProfileDoc>(await reader.doc(r.profile(booking.data.slug)));
      await readCalendarLock(tx, deps.db, uid);
      const startsAt = ms(request.requestedStart);
      const check = await checkSlot(reader, deps.db, calendar, startsAt, bookingOffer(booking.data), now, {
        excludeBookingId: booking.id
      });
      if (!check.free) return { status: 'slotTaken' as const };

      const endsAt = startsAt + booking.data.durationMinutes * 60_000;
      const mints = booking.data.client.email !== undefined;
      tx.update(booking.ref, {
        ...(mints ? { manageTokenHashes: withNewTokenHash(booking.data.manageTokenHashes, tokenHash(manageToken)) } : {}),
        startsAt: ts(startsAt),
        endsAt: ts(endsAt),
        purgeAt: ts(purgeAtFor(endsAt)),
        rescheduleCount: booking.data.rescheduleCount + 1,
        clientConfirmedAt: FieldValue.delete(),
        lateByMinutes: FieldValue.delete(),
        lateReportedAt: FieldValue.delete(),
        reminderSentAt: FieldValue.delete(),
        updatedAt: ts(now)
      });
      tx.update(requestRef, { status: 'accepted', respondedAt: ts(now), purgeAt: ts(purgeAtFor(endsAt)) });
      bumpCalendarLock(tx, deps.db, uid);
      const moved: BookingDoc = { ...booking.data, startsAt: ts(startsAt), endsAt: ts(endsAt) };
      return { status: 'accepted' as const, moved, name: profile?.displayName ?? '', ...(mints ? { manageToken } : {}) };
    });

    if (outcome.status === 'accepted') {
      await sendBookingEmail(deps, {
        template: 'bookingMoved',
        booking: outcome.moved,
        professionalName: outcome.name,
        ...(outcome.manageToken ? { manageToken: outcome.manageToken } : { linkToPage: true })
      });
    }
    return { status: outcome.status };
  }
});
