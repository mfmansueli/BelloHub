import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/public.js';
import { findBookingByToken, tokenHash } from '../lib/bookingAccess.js';
import { clientActions } from '../lib/clientActions.js';
import type { ContactDoc, IntakeFormDoc, PublicProfileDoc, RescheduleRequestDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { intakeIsCurrent } from '../lib/rules.js';
import { dataOf, ms, msOpt, plainReader, refs } from '../lib/store.js';

/**
 * The management page (Bk-9): the booking, the rules it was made under (D47: the booking's own snapshot, not the page's
 * current policy) and what the client may do right now.
 */
export const getBooking = defineUseCase({
  name: 'getBooking',
  access: 'token',
  ...contract.getBooking,
  async handle(deps, input, ctx) {
    await consumeRates(deps, [
      { scope: 'tokenCalls', subject: tokenHash(input.token), rate: RATE.tokenCallsToken },
      { scope: 'tokenIp', subject: ctx.ipHash, rate: RATE.tokenCallsIp }
    ]);
    const now = deps.now();
    const r = refs(deps.db);
    const { id, data: booking } = await findBookingByToken(plainReader, deps.db, input.token, now);
    const [profileSnap, contactSnap, intakeSnap, requestSnap] = await Promise.all([
      r.profile(booking.slug).get(),
      r.contact(booking.ownerUid, booking.phoneHash).get(),
      r.intakeForm(booking.ownerUid).get(),
      r.rescheduleRequest(id).get()
    ]);
    const profile = dataOf<PublicProfileDoc>(profileSnap);
    if (!profile) throw new AppError('NOT_FOUND');
    const contact = dataOf<ContactDoc>(contactSnap);
    const request = dataOf<RescheduleRequestDoc>(requestSnap);
    const actions = clientActions(booking, now);
    const confirmedAt = msOpt(booking.clientConfirmedAt);
    const intakePublished = dataOf<IntakeFormDoc>(intakeSnap) !== undefined;

    return {
      bookingId: id,
      status: booking.status === 'completed' ? ('confirmed' as const) : booking.status,
      phase: actions.phase,
      slug: booking.slug,
      professional: {
        displayName: profile.displayName,
        ...(profile.businessName ? { businessName: profile.businessName } : {}),
        ...(profile.whatsappE164 ? { whatsappE164: profile.whatsappE164 } : {})
      },
      service: { id: booking.serviceId, name: booking.serviceName },
      addOns: booking.addOns,
      guestCount: booking.guestCount,
      startsAt: iso(ms(booking.startsAt)),
      endsAt: iso(ms(booking.endsAt)),
      durationMinutes: booking.durationMinutes,
      timeZoneID: booking.timeZoneID,
      serverTime: iso(now),
      client: { name: booking.client.name },
      policy: booking.policy,
      rulesText: booking.rulesText ?? profile.rulesText,
      lateCancelCounts: booking.noShowPolicy ? booking.noShowPolicy.isOn && booking.noShowPolicy.lateCancelCounts : false,
      actions: {
        cancel: actions.cancel,
        reschedule: actions.reschedule,
        isInsideFreeWindow: actions.isInsideFreeWindow,
        hoursUntilStart: actions.hoursUntilStart,
        cancellationWouldBeLate: actions.cancellationWouldBeLate,
        canConfirmPresence: actions.canConfirmPresence,
        canReportLate: actions.canReportLate
      },
      ...(confirmedAt !== undefined ? { clientConfirmedAt: iso(confirmedAt) } : {}),
      ...(booking.lateByMinutes !== undefined ? { lateByMinutes: booking.lateByMinutes } : {}),
      rescheduleCount: booking.rescheduleCount,
      ...(request && (request.status === 'pending' || request.status === 'declined')
        ? { pendingReschedule: { requestedStart: iso(ms(request.requestedStart)), status: request.status } }
        : {}),
      intakeRequired: intakePublished && !intakeIsCurrent(msOpt(contact?.lastIntakeAt), now),
      tokenExpiresAt: iso(ms(booking.purgeAt))
    };
  }
});
