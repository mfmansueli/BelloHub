import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE, SIZE } from '../config/limits.js';
import { instantMs, iso } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import type { PublicProfileInput } from '../contracts/profile.js';
import { ensureAccountExists } from '../lib/account.js';
import { writeAudit } from '../lib/audit.js';
import { inboxKeyId } from '../lib/crypto.js';
import type { AccountDoc, IntakeFormDoc, PublicProfileDoc, SlugDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { applyInboxKey } from '../lib/keyring.js';
import { keyringUpdate } from '../lib/keyringUpdate.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

const bytes = (value: unknown): number => Buffer.byteLength(JSON.stringify(value), 'utf8');

function assertUnique(values: readonly string[], field: string): void {
  if (new Set(values).size !== values.length) throw new AppError('INVALID_ARGUMENT', { fields: [field] });
}

/** Validates what the schema cannot: sizes, uniqueness, and that the inbox key id really is the hash of the key. */
export function validateProfile(profile: PublicProfileInput): void {
  if (bytes({ ...profile, intake: undefined }) > SIZE.profileBytes) {
    throw new AppError('PAYLOAD_TOO_LARGE', { maxBytes: SIZE.profileBytes });
  }
  if (profile.intake) {
    if (bytes(profile.intake.template) > SIZE.intakeTemplateBytes) {
      throw new AppError('PAYLOAD_TOO_LARGE', { maxBytes: SIZE.intakeTemplateBytes });
    }
    if (bytes(profile.intake.consent) > SIZE.intakeConsentBytes) {
      throw new AppError('PAYLOAD_TOO_LARGE', { maxBytes: SIZE.intakeConsentBytes });
    }
  }
  assertUnique(profile.services.map((service) => service.id), 'profile.services');
  assertUnique(profile.addOns.map((addOn) => addOn.id), 'profile.addOns');
  assertUnique(profile.locales, 'profile.locales');
  if (inboxKeyId(profile.inboxKey.pub) !== profile.inboxKey.keyId) {
    throw new AppError('INVALID_ARGUMENT', { fields: ['profile.inboxKey'] });
  }
}

/** Publishes the page clients see. A profile with no health form removes any previously published one. */
export const publishProfile = defineUseCase({
  name: 'publishProfile',
  access: 'owner',
  ...contract.publishProfile,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'publish', uid, RATE.publishOwner);
    const profile = input.profile;
    validateProfile(profile);
    await ensureAccountExists(deps, uid, ctx);
    const r = refs(deps.db);
    const now = deps.now();

    const slug = await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const account = dataOf<AccountDoc>(await reader.doc(r.account(uid)));
      const slugName = account?.slug;
      if (!account || !slugName) throw new AppError('NOT_FOUND');
      const claim = dataOf<SlugDoc>(await reader.doc(r.slug(slugName)));
      if (claim?.ownerUid !== uid) throw new AppError('FORBIDDEN');

      const { intake, ...page } = profile;
      const { booking } = page;
      const { pausedUntil, ...bookingRest } = booking;
      const doc: PublicProfileDoc = {
        ...page,
        schemaVersion: 1,
        slug: slugName,
        booking: { ...bookingRest, ...(pausedUntil ? { pausedUntil: ts(instantMs(pausedUntil)) } : {}) },
        updatedAt: ts(now)
      };
      tx.set(r.profile(slugName), doc);

      if (intake) {
        tx.set(r.intakeForm(uid), {
          ownerUid: uid,
          slug: slugName,
          formVersion: intake.formVersion,
          template: intake.template,
          consent: intake.consent,
          updatedAt: ts(now)
        } satisfies IntakeFormDoc);
      } else {
        tx.delete(r.intakeForm(uid));
      }

      const applied = applyInboxKey(account.inboxKeyring, profile.inboxKey, now);
      // A key retired as compromised cannot come back through the profile either (D51).
      if ('failure' in applied) throw new AppError('INVALID_ARGUMENT', { fields: ['profile.inboxKey'] });
      if (applied.changed) {
        tx.update(r.account(uid), keyringUpdate(applied.keyring, now));
        writeAudit(tx, deps, { kind: 'inboxKeyChanged', uid, keyId: profile.inboxKey.keyId });
      }
      return slugName;
    });
    deps.log.info('profile.published', { uid });
    return { slug, updatedAt: iso(now) };
  }
});
