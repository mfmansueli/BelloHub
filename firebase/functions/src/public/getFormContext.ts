import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/public.js';
import { findBookingByToken, tokenHash } from '../lib/bookingAccess.js';
import type { ContactDoc, IntakeFormDoc, PublicProfileDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { intakeIsCurrent } from '../lib/rules.js';
import { dataOf, msOpt, plainReader, refs } from '../lib/store.js';

/**
 * What the browser needs to seal a form (docs/10 section 5, docs/06 section 3.5): the questions, the consent texts, the
 * professional's PUBLIC key, and only a flag for "already completed within 12 months". Nothing about the client.
 */
export const getFormContext = defineUseCase({
  name: 'getFormContext',
  access: 'token',
  ...contract.getFormContext,
  async handle(deps, input, ctx) {
    await consumeRates(deps, [
      { scope: 'tokenCalls', subject: tokenHash(input.token), rate: RATE.tokenCallsToken },
      { scope: 'tokenIp', subject: ctx.ipHash, rate: RATE.tokenCallsIp }
    ]);
    const now = deps.now();
    const r = refs(deps.db);
    const { id, data: booking } = await findBookingByToken(plainReader, deps.db, input.token, now);
    const [formSnap, profileSnap, contactSnap] = await Promise.all([
      r.intakeForm(booking.ownerUid).get(),
      r.profile(booking.slug).get(),
      r.contact(booking.ownerUid, booking.phoneHash).get()
    ]);
    const form = dataOf<IntakeFormDoc>(formSnap);
    const profile = dataOf<PublicProfileDoc>(profileSnap);
    if (!form || !profile) throw new AppError('NOT_FOUND');
    const contact = dataOf<ContactDoc>(contactSnap);
    return {
      bookingId: id,
      professional: { displayName: profile.displayName },
      formVersion: form.formVersion,
      template: form.template,
      consent: form.consent,
      inboxKey: profile.inboxKey,
      intakeCompletedWithinMonths: intakeIsCurrent(msOpt(contact?.lastIntakeAt), now)
    };
  }
});
