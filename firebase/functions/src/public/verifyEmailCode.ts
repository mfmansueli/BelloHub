import { defineUseCase } from '../app/UseCase.js';
import { EMAIL_CODE_MAX_ATTEMPTS, EMAIL_PROOF_TTL_SECONDS, RATE } from '../config/limits.js';
import * as contract from '../contracts/public.js';
import { safeEqualHex } from '../lib/crypto.js';
import type { EmailCodeDoc, EmailProofDoc } from '../lib/docs.js';
import { emailHashOf, proofHash } from '../lib/emailProof.js';
import { AppError } from '../lib/errors.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, ms, refs, ts } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';
import { emailCodeHash } from './sendEmailCode.js';

/** Turns a correct code into a short-lived, single-use proof that the caller controls the email (D31). */
export const verifyEmailCode = defineUseCase({
  name: 'verifyEmailCode',
  access: 'public',
  ...contract.verifyEmailCode,
  async handle(deps, input, ctx) {
    const emailHash = emailHashOf(deps.pepper, input.email);
    await consumeRate(deps, 'emailCodeVerify', `${ctx.ipHash}|${emailHash}`, RATE.emailCodeVerifyEmail);

    const now = deps.now();
    const r = refs(deps.db);
    const codeRef = r.emailCode(emailHash);
    const proof = deps.random.token();

    // A wrong guess must be COUNTED, so the transaction commits and the error is thrown afterwards.
    const outcome = await runTransaction(deps.db, async (tx) => {
      const doc = dataOf<EmailCodeDoc>(await tx.get(codeRef));
      if (!doc || ms(doc.expiresAt) <= now || doc.attempts >= EMAIL_CODE_MAX_ATTEMPTS) return 'invalid' as const;
      if (!safeEqualHex(doc.codeHash, emailCodeHash(deps.pepper, emailHash, input.code))) {
        if (doc.attempts + 1 >= EMAIL_CODE_MAX_ATTEMPTS) tx.delete(codeRef);
        else tx.update(codeRef, { attempts: doc.attempts + 1 });
        return 'invalid' as const;
      }
      tx.delete(codeRef);
      tx.set(r.emailProof(proofHash(proof)), {
        emailHash,
        expiresAt: ts(now + EMAIL_PROOF_TTL_SECONDS * 1000)
      } satisfies EmailProofDoc);
      return 'ok' as const;
    });
    if (outcome === 'invalid') throw new AppError('INVALID_CODE');
    return { proof, expiresInSeconds: 1800 as const };
  }
});
