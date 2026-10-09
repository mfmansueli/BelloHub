import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import type { PortalContentInput } from '../contracts/owner.js';
import type { PortalDoc, PublicProfileDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { PORTAL_IDLE_DAYS } from '../lib/rules.js';
import { dataOf, ms, refs, ts } from '../lib/store.js';
import { portalHash, portalIsLive } from '../owner/publishPortal.js';

const ONE_DAY_MS = 86_400_000;

/**
 * The client portal (Cl-2): only what the professional chose to publish. Each use slides the expiry forward so it
 * lapses after 180 days of inactivity (docs/06 section 5); a revoked or lapsed portal answers TOKEN_EXPIRED.
 */
export const getPortal = defineUseCase({
  name: 'getPortal',
  access: 'token',
  ...contract.getPortal,
  async handle(deps, input, ctx) {
    const hash = portalHash(input.token);
    await consumeRates(deps, [
      { scope: 'tokenCalls', subject: hash, rate: RATE.tokenCallsToken },
      { scope: 'tokenIp', subject: ctx.ipHash, rate: RATE.tokenCallsIp }
    ]);
    const now = deps.now();
    const r = refs(deps.db);
    const ref = r.portal(hash);
    const portal = dataOf<PortalDoc>(await ref.get());
    if (!portal) throw new AppError('NOT_FOUND');
    if (!portalIsLive(portal, now)) throw new AppError('TOKEN_EXPIRED');
    const profile = dataOf<PublicProfileDoc>(await r.profile(portal.slug).get());
    if (!profile) throw new AppError('NOT_FOUND');

    // Slide the expiry at most once a day, so reading is not a write storm.
    const last = portal.lastAccessAt ? ms(portal.lastAccessAt) : 0;
    let expiresAt = ms(portal.expiresAt);
    if (now - last > ONE_DAY_MS) {
      expiresAt = now + PORTAL_IDLE_DAYS * ONE_DAY_MS;
      await ref.update({ lastAccessAt: ts(now), expiresAt: ts(expiresAt) });
    }

    const content = portal.content as unknown as PortalContentInput;
    return {
      slug: portal.slug,
      professional: {
        displayName: profile.displayName,
        ...(profile.businessName ? { businessName: profile.businessName } : {}),
        ...(profile.whatsappE164 ? { whatsappE164: profile.whatsappE164 } : {})
      },
      clientName: content.clientName,
      upcoming: content.upcoming ?? [],
      ...(content.next ? { next: content.next } : {}),
      past: content.past,
      aftercare: content.aftercare,
      products: content.products,
      ...(content.rebook ? { rebook: { serviceId: content.rebook.serviceId, addOnIds: content.rebook.addOnIds } } : {}),
      expiresAt: iso(expiresAt)
    };
  }
});
