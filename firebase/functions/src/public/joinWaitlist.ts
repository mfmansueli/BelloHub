import { defineUseCase } from '../app/UseCase.js';
import { MAX_WAITING_PER_OWNER, RATE } from '../config/limits.js';
import * as contract from '../contracts/public.js';
import { sha256Hex } from '../lib/crypto.js';
import type { PublicProfileDoc, SlugDoc, WaitlistDoc } from '../lib/docs.js';
import { phoneHashOf } from '../lib/emailProof.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { dataOf, refs, ts } from '../lib/store.js';
import { addDays, daysBetween, instantAtLocal, localDateOf } from '../lib/time.js';
import { notifyOwner } from '../push/notifyOwner.js';

const MAX_RANGE = 60;
const KEEP_DAYS_AFTER = 7;

/**
 * "Join the waitlist" (Bk-4) when no time fits: name, phone and a day range, no verification (App Check and tight rate
 * limits keep it from being abused). Operational data, removed 7 days after the last day. The same person, service and
 * range twice is one entry.
 */
export const joinWaitlist = defineUseCase({
  name: 'joinWaitlist',
  access: 'public',
  ...contract.joinWaitlist,
  async handle(deps, input, ctx) {
    const r = refs(deps.db);
    const claim = dataOf<SlugDoc>(await r.slug(input.slug).get());
    const profile = dataOf<PublicProfileDoc>(await r.profile(input.slug).get());
    if (!claim || !profile) throw new AppError('NOT_FOUND');

    const phoneHash = phoneHashOf(deps.pepper, input.phone);
    await consumeRates(deps, [
      { scope: 'waitlistIp', subject: ctx.ipHash, rate: RATE.waitlistIp },
      { scope: 'waitlistPhone', subject: phoneHash, rate: RATE.waitlistPhoneDay }
    ]);

    const now = deps.now();
    const today = localDateOf(now, profile.timeZoneID);
    const span = daysBetween(input.dayFrom, input.dayTo);
    if (span < 0 || span > MAX_RANGE || input.dayTo < today) throw new AppError('INVALID_ARGUMENT', { fields: ['dayTo'] });
    const service = input.serviceId ? profile.services.find((candidate) => candidate.id === input.serviceId) : undefined;
    if (input.serviceId && !service) throw new AppError('NOT_FOUND');

    const waiting = await r.waitlist().where('ownerUid', '==', claim.ownerUid).where('status', '==', 'waiting').count().get();
    if (waiting.data().count >= MAX_WAITING_PER_OWNER) throw new AppError('RATE_LIMITED', { retryAfterSeconds: 3600 });

    const id = sha256Hex(`${claim.ownerUid}|${phoneHash}|${input.serviceId ?? ''}|${input.dayFrom}|${input.dayTo}`).slice(0, 32);
    const endOfLastDay = instantAtLocal(addDays(input.dayTo, 1), 0, profile.timeZoneID);
    const doc: WaitlistDoc = {
      ownerUid: claim.ownerUid,
      slug: input.slug,
      name: input.name,
      phone: input.phone,
      phoneHash,
      locale: input.locale,
      ...(service ? { serviceId: service.id, serviceName: service.name } : {}),
      dayFrom: input.dayFrom,
      dayTo: input.dayTo,
      status: 'waiting',
      createdAt: ts(now),
      expiresAt: ts(endOfLastDay + KEEP_DAYS_AFTER * 86_400_000)
    };
    let created = true;
    try {
      await r.waitlistEntry(id).create(doc);
    } catch (error) {
      const code = (error as { code?: unknown }).code;
      if (code !== 6 && code !== 'already-exists') throw error;
      created = false;
    }
    if (created) await notifyOwner(deps, claim.ownerUid, { kind: 'waitlist', id });
    return { ok: true as const };
  }
});
