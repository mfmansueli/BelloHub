import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { RESERVED_SLUGS, SlugSchema } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import type { SlugDoc } from '../lib/docs.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, refs } from '../lib/store.js';

/** Live check while she types her booking address. Her own current slug is "available" to her. */
export const isSlugAvailable = defineUseCase({
  name: 'isSlugAvailable',
  access: 'owner',
  ...contract.isSlugAvailable,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'slugCheck', uid, RATE.slugCheckOwner);
    if (RESERVED_SLUGS.has(input.slug)) return { available: false, reason: 'reserved' as const };
    if (!SlugSchema.safeParse(input.slug).success) return { available: false, reason: 'invalid' as const };
    const claim = dataOf<SlugDoc>(await refs(deps.db).slug(input.slug).get());
    if (claim && claim.ownerUid !== uid) return { available: false, reason: 'taken' as const };
    return { available: true };
  }
});
