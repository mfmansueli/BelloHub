import { defineUseCase } from '../app/UseCase.js';
import { instantMs } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import { createBookingCore } from '../lib/bookingCreate.js';
import type { Proof } from '../lib/bookingCreate.js';
import { AppError } from '../lib/errors.js';

/**
 * Makes a booking (D32): verified contact, one transaction, exactly one winner per slot. The result is a status, not an
 * error, for the four normal outcomes (confirmed, waiting for approval, time taken, paused).
 *
 * Besides the two proofs (phone token, e-mail proof) a client may show a trusted-device token (`device`, a returning
 * client on the same page with the same e-mail) or none at all (`whatsapp`: she could not receive the code and confirms
 * with the professional on WhatsApp, so the booking is always a request flagged as unverified). Every method but
 * `phone` needs `client.email`: it is what the proof is about, or what the approval e-mail goes to.
 */
export const createBooking = defineUseCase({
  name: 'createBooking',
  access: 'public',
  ...contract.createBooking,
  async handle(deps, input, ctx) {
    let proof: Proof;
    const verification = input.verification;
    if (verification.method === 'phone') {
      const { phoneE164 } = await deps.phoneVerifier.verify(verification.idToken, deps.now());
      if (phoneE164 !== input.client.phone) throw new AppError('VERIFICATION_FAILED');
      proof = { kind: 'phone' };
    } else {
      if (!input.client.email) throw new AppError('INVALID_ARGUMENT', { fields: ['client.email'] });
      proof =
        verification.method === 'email'
          ? { kind: 'email', proof: verification.proof }
          : verification.method === 'device'
            ? { kind: 'device', token: verification.token }
            : { kind: 'whatsapp' };
    }
    return createBookingCore(deps, {
      slug: input.slug,
      offer: input,
      startsAt: instantMs(input.startsAt),
      client: input.client,
      note: input.note === '' ? undefined : input.note,
      idempotencyKey: input.idempotencyKey,
      holdKey: input.holdKey,
      origin: 'bookingLink',
      proof,
      ipHash: ctx.ipHash
    });
  }
});
