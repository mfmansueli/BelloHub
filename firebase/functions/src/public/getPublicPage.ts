import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { SMS_CALLING_CODES } from '../config/smsRegions.js';
import * as contract from '../contracts/public.js';
import type { IntakeFormDoc, PublicProfileDoc, SlugDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { profileView } from '../lib/profileView.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, refs } from '../lib/store.js';

/** The booking page's data. Replaces a direct Firestore read so the web needs no Firestore SDK and can be rate limited. */
export const getPublicPage = defineUseCase({
  name: 'getPublicPage',
  access: 'public',
  ...contract.getPublicPage,
  async handle(deps, input, ctx) {
    await consumeRate(deps, 'publicPage', ctx.ipHash, RATE.publicPageIp);
    const r = refs(deps.db);
    const [profileSnap, claimSnap] = await Promise.all([r.profile(input.slug).get(), r.slug(input.slug).get()]);
    const profile = dataOf<PublicProfileDoc>(profileSnap);
    const claim = dataOf<SlugDoc>(claimSnap);
    if (!profile || !claim) throw new AppError('NOT_FOUND');
    const intake = dataOf<IntakeFormDoc>(await r.intakeForm(claim.ownerUid).get());
    return {
      profile: profileView(profile),
      intakeAvailable: intake !== undefined,
      features: { whatsAppAutomation: deps.settings.whatsAppAutomation, smsCallingCodes: [...SMS_CALLING_CODES] },
      serverTime: new Date(deps.now()).toISOString()
    };
  }
});
