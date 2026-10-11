import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { MANAGE_LINK_REUSE_MINUTES, RATE } from '../config/limits.js';
import { iso } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import { ownerLinkToken, tokenHash, withNewTokenHash } from '../lib/bookingAccess.js';
import { ACTIVE_BOOKING_STATUSES } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { loadOwnedBooking } from '../lib/ownedBooking.js';
import { consumeRate } from '../lib/rateLimit.js';
import { ms, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

const REUSE_MS = MANAGE_LINK_REUSE_MINUTES * 60_000;

/**
 * The client's own link to change or cancel (`<web>/m/<token>`), for a message the professional sends from the app
 * ("Message <client>", 3.6). The app cannot build it: the server keeps only token hashes. It reuses the manage-token
 * machinery (hash at rest, at most five valid per booking, the oldest dropped) and is idempotent for
 * `MANAGE_LINK_REUSE_MINUTES`: the token is derived from the pepper, the booking id and `ownerLinkMintedAt`, so a second
 * call inside the window recomputes the same link (as long as five newer links did not push it out) instead of using up
 * one more. Only her own booking, only while it holds time and has not ended. Logs ids only; the token and the URL never
 * leave the response.
 */
export const mintManageLink = defineUseCase({
  name: 'mintManageLink',
  access: 'owner',
  ...contract.mintManageLink,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'manageLinkOwner', uid, RATE.manageLinkOwner);
    const now = deps.now();

    const outcome = await runTransaction(deps.db, async (tx) => {
      const booking = await loadOwnedBooking(txReader(tx), deps.db, uid, input.bookingId);
      const data = booking.data;
      if (!ACTIVE_BOOKING_STATUSES.includes(data.status) || now >= ms(data.endsAt)) {
        throw new AppError('BOOKING_NOT_ACTIVE', { status: data.status });
      }
      const purgeAt = ms(data.purgeAt);
      const previous = data.ownerLinkMintedAt === undefined ? undefined : ms(data.ownerLinkMintedAt);
      if (previous !== undefined && now >= previous && now - previous < REUSE_MS) {
        const token = ownerLinkToken(deps.pepper, booking.id, previous);
        if (data.manageTokenHashes.includes(tokenHash(token))) return { token, purgeAt, reused: true };
      }
      const token = ownerLinkToken(deps.pepper, booking.id, now);
      tx.update(booking.ref, {
        manageTokenHashes: withNewTokenHash(data.manageTokenHashes, tokenHash(token)),
        ownerLinkMintedAt: ts(now)
      });
      return { token, purgeAt, reused: false };
    });

    deps.log.info('manageLink.minted', { uid, bookingId: input.bookingId, status: outcome.reused ? 'reused' : 'new' });
    return { url: `${deps.settings.webBaseUrl}/m/${outcome.token}`, expiresAt: iso(outcome.purgeAt) };
  }
});
