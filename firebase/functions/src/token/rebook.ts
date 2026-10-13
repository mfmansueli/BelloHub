import type { Deps } from '../app/Deps.js';
import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { instantMs } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import type { PortalContentInput } from '../contracts/owner.js';
import { findBookingByToken, tokenHash } from '../lib/bookingAccess.js';
import { createBookingCore } from '../lib/bookingCreate.js';
import type { BookingClient } from '../lib/bookingCreate.js';
import type { PortalDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { dataOf, plainReader, refs } from '../lib/store.js';
import { portalHash, portalIsLive } from '../owner/publishPortal.js';

interface Identity {
  slug: string;
  client: BookingClient;
  serviceId: string;
  addOnIds: string[];
  guests: number;
}

/**
 * "Book again" (Cl-3). A manage link of an earlier booking, or a portal link with a `rebook` section, proves who she is, so
 * there is no new verification and she is not treated as a new client (D42: a phone already registered books freely).
 * The professional's pause, the no-show action and a "stopped" client still apply, inside the shared booking code.
 */
export const rebook = defineUseCase({
  name: 'rebook',
  access: 'token',
  ...contract.rebook,
  async handle(deps, input, ctx) {
    await consumeRates(deps, [
      { scope: 'tokenAction', subject: tokenHash(input.token), rate: RATE.tokenActionsToken },
      { scope: 'tokenIp', subject: ctx.ipHash, rate: RATE.tokenCallsIp }
    ]);
    const now = deps.now();
    const identity = await identify(deps, input.token, now);
    const sameService = input.serviceId === undefined || input.serviceId === identity.serviceId;
    const sameAddOns = input.addOnIds === undefined ||
      (input.addOnIds.length === identity.addOnIds.length && input.addOnIds.every((id) => identity.addOnIds.includes(id)));
    return createBookingCore(deps, {
      slug: identity.slug,
      offer: {
        serviceId: input.serviceId ?? identity.serviceId,
        addOnIds: input.addOnIds ?? identity.addOnIds,
        guests: sameService && sameAddOns ? identity.guests : 0
      },
      startsAt: instantMs(input.startsAt),
      client: identity.client,
      idempotencyKey: input.idempotencyKey,
      origin: 'rebook',
      proof: { kind: 'token' },
      ipHash: ctx.ipHash
    });
  }
});

async function identify(deps: Deps, token: string, now: number): Promise<Identity> {
  const portal = dataOf<PortalDoc>(await refs(deps.db).portal(portalHash(token)).get());
  if (portal) {
    if (!portalIsLive(portal, now)) throw new AppError('TOKEN_EXPIRED');
    const content = portal.content as unknown as PortalContentInput;
    if (!content.rebook) throw new AppError('NOT_ALLOWED');
    return {
      slug: portal.slug,
      client: content.rebook.client,
      serviceId: content.rebook.serviceId,
      addOnIds: content.rebook.addOnIds,
      guests: 0
    };
  }
  const booking = await findBookingByToken(plainReader, deps.db, token, now);
  return {
    slug: booking.data.slug,
    client: booking.data.client,
    serviceId: booking.data.serviceId,
    addOnIds: booking.data.addOns.map((addOn) => addOn.id),
    guests: booking.data.guestCount
  };
}
