import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE, SIZE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import { ensureAccountExists } from '../lib/account.js';
import { writeAudit } from '../lib/audit.js';
import { fromBase64url, sha256Hex } from '../lib/crypto.js';
import type { AccountDoc, PortalDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRate } from '../lib/rateLimit.js';
import { PORTAL_IDLE_DAYS } from '../lib/rules.js';
import { dataOf, ms, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

export function portalHash(token: string): string {
  return sha256Hex(`portal:${token}`);
}

/** A portal token made by the app must really be 128 random bits, not a pattern someone could guess. */
function looksRandom(token: string): boolean {
  const bytes = fromBase64url(token);
  return bytes !== null && bytes.length === 16 && new Set(bytes).size >= 6;
}

/**
 * Publishes what she chose to share with one client (aftercare, products, next visit). The app makes the token, the
 * server stores only its hash; `revoke` makes it unusable at once. Expires after 180 idle days, sliding (docs/06 section 5).
 */
export const publishPortal = defineUseCase({
  name: 'publishPortal',
  access: 'owner',
  ...contract.publishPortal,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'publish', uid, RATE.publishOwner);
    if (!looksRandom(input.token)) throw new AppError('INVALID_ARGUMENT', { fields: ['token'] });
    if (!input.revoke && !input.content) throw new AppError('INVALID_ARGUMENT', { fields: ['content'] });
    if (input.content && Buffer.byteLength(JSON.stringify(input.content)) > SIZE.portalBytes) {
      throw new AppError('PAYLOAD_TOO_LARGE', { maxBytes: SIZE.portalBytes });
    }
    await ensureAccountExists(deps, uid, ctx);
    const r = refs(deps.db);
    const now = deps.now();
    const expiresAt = now + PORTAL_IDLE_DAYS * 86_400_000;

    await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const account = dataOf<AccountDoc>(await reader.doc(r.account(uid)));
      const existing = dataOf<PortalDoc>(await reader.doc(r.portal(portalHash(input.token))));
      if (existing && existing.ownerUid !== uid) throw new AppError('CONFLICT');
      const ref = r.portal(portalHash(input.token));
      if (input.revoke) {
        if (existing) {
          // The content goes with the access: a revoked portal keeps nothing she published.
          tx.update(ref, { revokedAt: ts(now), content: {}, updatedAt: ts(now) });
          writeAudit(tx, deps, { kind: 'portalRevoked', uid });
        }
        return;
      }
      if (!account?.slug) throw new AppError('NOT_FOUND');
      const doc: PortalDoc = {
        ownerUid: uid,
        slug: account.slug,
        clientRef: input.clientRef,
        content: input.content as unknown as Record<string, unknown>,
        createdAt: existing ? existing.createdAt : ts(now),
        updatedAt: ts(now),
        expiresAt: ts(expiresAt),
        ...(existing?.lastAccessAt ? { lastAccessAt: existing.lastAccessAt } : {})
        // A republish after a revoke brings the portal back: `revokedAt` is intentionally not copied.
      };
      tx.set(ref, doc);
    });
    return { ok: true as const, expiresAt: iso(expiresAt) };
  }
});

export function portalIsLive(doc: PortalDoc, now: number): boolean {
  return !doc.revokedAt && ms(doc.expiresAt) > now;
}
