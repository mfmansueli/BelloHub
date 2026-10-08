import { defineUseCase } from '../app/UseCase.js';
import { EMAIL_CODE_TTL_SECONDS, EMAIL_RESEND_SECONDS, RATE } from '../config/limits.js';
import * as contract from '../contracts/public.js';
import { keyedHash } from '../lib/crypto.js';
import type { EmailCodeDoc, PublicProfileDoc, SlugDoc } from '../lib/docs.js';
import { emailHashOf } from '../lib/emailProof.js';
import { AppError } from '../lib/errors.js';
import { consumeRates } from '../lib/rateLimit.js';
import { dataOf, ms, refs, ts } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

export function emailCodeHash(pepper: string, emailHash: string, code: string): string {
  return keyedHash(pepper, 'emailcode', `${emailHash}:${code}`);
}

/**
 * Emails a 6-digit code (D31, D37): the always-available fallback when SMS fails or the country is not on the SMS
 * allow-list. The code is stored hashed, expires in 10 minutes, and a resend waits 30 seconds. The answer is the same
 * whether or not the address is known to anyone.
 */
export const sendEmailCode = defineUseCase({
  name: 'sendEmailCode',
  access: 'public',
  ...contract.sendEmailCode,
  async handle(deps, input, ctx) {
    const r = refs(deps.db);
    const claim = dataOf<SlugDoc>(await r.slug(input.slug).get());
    if (!claim) throw new AppError('NOT_FOUND');
    if (!deps.messenger.emailAvailable) throw new AppError('NOT_CONFIGURED');

    const emailHash = emailHashOf(deps.pepper, input.email);
    await consumeRates(deps, [
      { scope: 'emailCodeIp', subject: ctx.ipHash, rate: RATE.emailCodeIp },
      { scope: 'emailCodeEmail', subject: emailHash, rate: RATE.emailCodeEmail },
      { scope: 'emailCodeOwner', subject: claim.ownerUid, rate: RATE.emailCodeOwnerDay }
    ]);

    const now = deps.now();
    const code = deps.settings.fixedEmailCode ?? deps.random.code6();
    const ref = r.emailCode(emailHash);
    await runTransaction(deps.db, async (tx) => {
      const previous = dataOf<EmailCodeDoc>(await tx.get(ref));
      if (previous && now - ms(previous.sentAt) < EMAIL_RESEND_SECONDS * 1000) {
        const wait = Math.ceil((EMAIL_RESEND_SECONDS * 1000 - (now - ms(previous.sentAt))) / 1000);
        throw new AppError('RATE_LIMITED', { retryAfterSeconds: wait });
      }
      tx.set(ref, {
        codeHash: emailCodeHash(deps.pepper, emailHash, code),
        purpose: input.purpose,
        attempts: 0,
        sentAt: ts(now),
        expiresAt: ts(now + EMAIL_CODE_TTL_SECONDS * 1000)
      } satisfies EmailCodeDoc);
    });

    const profile = dataOf<PublicProfileDoc>(await r.profile(input.slug).get());
    try {
      await deps.messenger.sendEmail({
        template: 'verificationCode',
        to: input.email,
        locale: input.locale,
        vars: { code, professional: profile?.displayName ?? '' }
      });
    } catch (error) {
      await ref.delete();
      throw error;
    }
    deps.log.info('emailCode.sent', { kind: input.purpose });
    return { resendAfterSeconds: 30 as const, expiresInSeconds: 600 as const };
  }
});
