import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { instantMs } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import { marksOf, withMark, withoutMark, writeContact } from '../lib/contacts.js';
import type { AvailabilityDoc, ContactDoc } from '../lib/docs.js';
import { phoneHashOf } from '../lib/emailProof.js';
import { AppError } from '../lib/errors.js';
import { loadOwnedBooking } from '../lib/ownedBooking.js';
import { consumeRate } from '../lib/rateLimit.js';
import { countedNoShows } from '../lib/rules.js';
import { dataOf, msOpt, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * Her own no-show markings, pushed by the app (docs/11 section 2): the server counts them per professional and per
 * phone, within the policy's counting months, to apply "approve new bookings" or "pause online" (D13). Marks are
 * idempotent by id, "forgive" removes one, "reset" starts the count from zero. No names, no content.
 */
export const markNoShow = defineUseCase({
  name: 'markNoShow',
  access: 'owner',
  ...contract.markNoShow,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    if (input.action !== 'reset' && !input.markId) throw new AppError('INVALID_ARGUMENT', { fields: ['markId'] });
    const phoneHash = phoneHashOf(deps.pepper, input.phone);
    const r = refs(deps.db);
    const now = deps.now();

    const counted = await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const contact = dataOf<ContactDoc>(await reader.doc(r.contact(uid, phoneHash)));
      const availability = dataOf<AvailabilityDoc>(await reader.doc(r.availability(uid)));
      const booking = input.bookingId ? await loadOwnedBooking(reader, deps.db, uid, input.bookingId) : undefined;

      let patch: Partial<ContactDoc>;
      if (input.action === 'mark') {
        const at = input.markedAt ? instantMs(input.markedAt) : now;
        patch = { marks: withMark(contact?.marks, { id: input.markId ?? '', at, kind: 'noShow' }) };
        if (booking?.data.status === 'confirmed') {
          tx.update(booking.ref, { status: 'noShow', updatedAt: ts(now) });
        }
      } else if (input.action === 'forgive') {
        patch = { marks: withoutMark(contact?.marks, input.markId ?? '') };
      } else {
        patch = { noShowResetAt: ts(now) };
      }
      writeContact(tx, r, uid, phoneHash, contact, patch, now);

      // The count the app shows: her own policy's window and late-cancel setting, whether or not protection is switched on.
      const updated = { ...contact, ...patch } as ContactDoc;
      const policy = {
        isOn: true,
        limit: availability?.noShow.limit ?? 3,
        action: availability?.noShow.action ?? 'tell',
        lateCancelCounts: availability?.noShow.lateCancelCounts ?? false,
        countingMonths: availability?.noShow.countingMonths ?? 12
      } as const;
      return countedNoShows(policy, marksOf(updated), msOpt(updated.noShowResetAt), now);
    });
    return { counted };
  }
});
