import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/owner.js';
import { deleteClientData } from '../lib/deletion.js';
import { phoneHashOf } from '../lib/emailProof.js';
import { AppError } from '../lib/errors.js';
import { consumeRate } from '../lib/rateLimit.js';

/**
 * She deleted a client: the server forgets that client too (D30). The registration counter and its ledger are NOT touched,
 * so deleting a client never gives a free registration back (D42).
 */
export const deleteClientServerData = defineUseCase({
  name: 'deleteClientServerData',
  access: 'owner',
  ...contract.deleteClientServerData,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    if (!input.phone && !input.bookingIds?.length && !input.portalClientRef) {
      throw new AppError('INVALID_ARGUMENT', { fields: ['phone'] });
    }
    const deleted = await deleteClientData(deps, uid, {
      phoneHash: input.phone ? phoneHashOf(deps.pepper, input.phone) : undefined,
      bookingIds: input.bookingIds,
      portalClientRef: input.portalClientRef
    });
    return { deleted };
  }
});
