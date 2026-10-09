import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { OFFER_DEFAULT_MINUTES, RATE } from '../config/limits.js';
import { instantMs, iso } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import { ensureAccountExists } from '../lib/account.js';
import { bumpCalendarLock, checkSlot, loadCalendar, readCalendarLock, resolveOffer } from '../lib/calendar.js';
import type { HoldDoc, WaitlistDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { holdKeyHash } from '../lib/holds.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

/**
 * When a time frees up she offers it to someone on the waitlist (Waitlist 2.9): the server holds the slot for them and
 * returns a one-time key for the link she sends (`<web>/<slug>/time?offer=<holdKey>`). Booking through the link marks
 * the entry booked. The key is the only secret; the server stores its hash.
 */
export const offerWaitlistSlot = defineUseCase({
  name: 'offerWaitlistSlot',
  access: 'owner',
  ...contract.offerWaitlistSlot,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'ownerCalls', uid, RATE.ownerCalls);
    const account = await ensureAccountExists(deps, uid, ctx);
    if (!account.slug) throw new AppError('NOT_FOUND');
    const slug = account.slug;
    const r = refs(deps.db);
    const now = deps.now();
    const startsAt = instantMs(input.startsAt);
    const holdKey = deps.random.token();
    const minutes = input.holdMinutes ?? OFFER_DEFAULT_MINUTES;

    return runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const entry = dataOf<WaitlistDoc>(await reader.doc(r.waitlistEntry(input.waitlistId)));
      if (entry?.ownerUid !== uid) throw new AppError('NOT_FOUND');
      if (entry.status === 'booked') throw new AppError('BOOKING_NOT_ACTIVE', { status: entry.status });
      const calendar = await loadCalendar(reader, deps.db, slug);
      if (!calendar) throw new AppError('NOT_FOUND');
      const offer = resolveOffer(calendar.profile, input);
      await readCalendarLock(tx, deps.db, uid);
      const check = await checkSlot(reader, deps.db, calendar, startsAt, offer.durationMinutes, now);
      if (!check.free) return { status: 'slotTaken' as const };

      const expiresAt = now + minutes * 60_000;
      const holdRef = r.holds().doc();
      tx.create(holdRef, {
        ownerUid: uid,
        slug,
        serviceId: offer.serviceId,
        addOnIds: offer.addOns.map((addOn) => addOn.id),
        guests: offer.guests,
        startsAt: ts(startsAt),
        endsAt: ts(startsAt + offer.durationMinutes * 60_000),
        expiresAt: ts(expiresAt),
        holdKeyHash: holdKeyHash(holdKey),
        kind: 'offer',
        waitlistId: input.waitlistId
      } satisfies HoldDoc);
      tx.update(r.waitlistEntry(input.waitlistId), { status: 'offered', offeredAt: ts(now) });
      bumpCalendarLock(tx, deps.db, uid);
      return { status: 'offered' as const, holdKey, holdId: holdRef.id, expiresAt: iso(expiresAt) };
    });
  }
});
