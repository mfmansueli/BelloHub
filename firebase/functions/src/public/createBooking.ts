import { defineUseCase } from '../app/UseCase.js';
import { instantMs } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import { createBookingCore } from '../lib/bookingCreate.js';
import type { Proof } from '../lib/bookingCreate.js';
import { AppError } from '../lib/errors.js';

/**
 * Makes a booking (D32): verified contact, one transaction, exactly one winner per slot. The result is a status, not an
 * error, for the four normal outcomes (confirmed, waiting for approval, time taken, paused).
 */
export const createBooking = defineUseCase({
  name: 'createBooking',
  access: 'public',
  ...contract.createBooking,
  async handle(deps, input, ctx) {
    let proof: Proof;
    if (input.verification.method === 'phone') {
      const { phoneE164 } = await deps.phoneVerifier.verify(input.verification.idToken, deps.now());
      if (phoneE164 !== input.client.phone) throw new AppError('VERIFICATION_FAILED');
      proof = { kind: 'phone' };
    } else {
      if (!input.client.email) throw new AppError('INVALID_ARGUMENT', { fields: ['client.email'] });
      proof = { kind: 'email', proof: input.verification.proof };
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
