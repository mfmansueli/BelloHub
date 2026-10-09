import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import type { SlugDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { findHoldsByKey } from '../lib/holds.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, ms, plainReader, refs } from '../lib/store.js';

/** Opens a waitlist offer link: what was held for this person and until when (docs/10 section 3, "Waitlist"). */
export const getHold = defineUseCase({
  name: 'getHold',
  access: 'public',
  ...contract.getHold,
  async handle(deps, input, ctx) {
    await consumeRate(deps, 'hold', ctx.ipHash, RATE.holdIp);
    const claim = dataOf<SlugDoc>(await refs(deps.db).slug(input.slug).get());
    if (!claim) throw new AppError('NOT_FOUND');
    const [hold] = await findHoldsByKey(plainReader, deps.db, claim.ownerUid, input.holdKey);
    if (!hold) throw new AppError('NOT_FOUND');
    if (ms(hold.data.expiresAt) <= deps.now()) throw new AppError('TOKEN_EXPIRED');
    return {
      serviceId: hold.data.serviceId,
      addOnIds: hold.data.addOnIds,
      guests: hold.data.guests,
      startsAt: iso(ms(hold.data.startsAt)),
      endsAt: iso(ms(hold.data.endsAt)),
      expiresAt: iso(ms(hold.data.expiresAt))
    };
  }
});
