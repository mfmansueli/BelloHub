import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import { tokenHash, withNewTokenHash } from '../lib/bookingAccess.js';
import type { BookingDoc, SlugDoc } from '../lib/docs.js';
import { ACTIVE_BOOKING_STATUSES } from '../lib/docs.js';
import { emailHashOf, peekEmailProof, phoneHashOf, useEmailProof } from '../lib/emailProof.js';
import { AppError } from '../lib/errors.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, ms, refs, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * "Find my appointment" (Bk-11): she proves she controls the phone (SMS) or the email (code) she booked with and gets her
 * upcoming bookings of this professional. The server cannot read back a token it only stores hashed, so each found
 * booking gets one more valid link (at most five; the oldest is dropped). Nothing is returned for a phone or email that
 * has no bookings, and the answer looks the same: no one learns who is a client.
 */
export const findBookings = defineUseCase({
  name: 'findBookings',
  access: 'public',
  ...contract.findBookings,
  async handle(deps, input, ctx) {
    const r = refs(deps.db);
    const claim = dataOf<SlugDoc>(await r.slug(input.slug).get());
    if (!claim) throw new AppError('NOT_FOUND');
    const now = deps.now();

    let field: 'phoneHash' | 'emailHash';
    let hash: string;
    let proofEmail: string | undefined;
    if (input.verification.method === 'phone') {
      if (!input.phone) throw new AppError('INVALID_ARGUMENT', { fields: ['phone'] });
      const { phoneE164 } = await deps.phoneVerifier.verify(input.verification.idToken, now);
      if (phoneE164 !== input.phone) throw new AppError('VERIFICATION_FAILED');
      field = 'phoneHash';
      hash = phoneHashOf(deps.pepper, input.phone);
    } else {
      if (!input.email) throw new AppError('INVALID_ARGUMENT', { fields: ['email'] });
      field = 'emailHash';
      hash = emailHashOf(deps.pepper, input.email);
      proofEmail = input.email;
    }
    // The caller's address pays first; the contact's allowance only once the proof looks real (see peekEmailProof).
    await consumeRate(deps, 'findIp', ctx.ipHash, RATE.findBookingsIp);
    if (input.verification.method === 'email' && proofEmail) {
      await peekEmailProof(deps.db, deps.pepper, input.verification.proof, proofEmail, now);
    }
    await consumeRate(deps, 'findContact', hash, RATE.findBookingsPhone);

    return runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const release =
        input.verification.method === 'email' && proofEmail
          ? await useEmailProof(tx, deps.db, deps.pepper, input.verification.proof, proofEmail, now)
          : undefined;
      const found = await reader.query(r.bookings().where('ownerUid', '==', claim.ownerUid).where(field, '==', hash));
      const upcoming = found.docs
        .map((doc) => ({ ref: doc.ref, id: doc.id, data: doc.data() as BookingDoc }))
        .filter(({ data }) => ACTIVE_BOOKING_STATUSES.includes(data.status) && ms(data.endsAt) > now)
        .sort((a, b) => ms(a.data.startsAt) - ms(b.data.startsAt));

      const bookings = upcoming.map(({ ref, id, data }) => {
        const manageToken = deps.random.token();
        tx.update(ref, { manageTokenHashes: withNewTokenHash(data.manageTokenHashes, tokenHash(manageToken)) });
        return {
          bookingId: id,
          manageToken,
          serviceName: data.serviceName,
          startsAt: iso(ms(data.startsAt)),
          endsAt: iso(ms(data.endsAt)),
          timeZoneID: data.timeZoneID,
          status: data.status as 'confirmed' | 'pendingApproval'
        };
      });
      release?.();
      return { bookings };
    });
  }
});
