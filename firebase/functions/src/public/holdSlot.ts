import { defineUseCase } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import * as contract from '../contracts/public.js';
import { instantMs, iso } from '../contracts/common.js';
import { bumpCalendarLock, checkSlot, loadCalendar, readCalendarLock, resolveOffer } from '../lib/calendar.js';
import type { HoldDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { findHoldsByKey, holdKeyHash } from '../lib/holds.js';
import { consumeRate } from '../lib/rateLimit.js';
import { refs, ts, txReader } from '../lib/store.js';
import { HOLD_MINUTES } from '../lib/rules.js';
import { runTransaction } from '../lib/tx.js';

/** A 5 minute soft hold so two people do not collide while one of them types her details (docs/10 section 3). */
export const holdSlot = defineUseCase({
  name: 'holdSlot',
  access: 'public',
  ...contract.holdSlot,
  async handle(deps, input, ctx) {
    await consumeRate(deps, 'hold', ctx.ipHash, RATE.holdIp);
    const now = deps.now();
    const startsAt = instantMs(input.startsAt);

    return runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const calendar = await loadCalendar(reader, deps.db, input.slug);
      if (!calendar) throw new AppError('NOT_FOUND');
      const offer = resolveOffer(calendar.profile, input);

      const pausedUntil = calendar.profile.booking.pausedUntil;
      if (!calendar.profile.booking.acceptingBookings || (pausedUntil && pausedUntil.toMillis() > now)) {
        return { status: 'paused' as const };
      }

      await readCalendarLock(tx, deps.db, calendar.ownerUid);
      const previous = await findHoldsByKey(reader, deps.db, calendar.ownerUid, input.holdKey);
      const check = await checkSlot(reader, deps.db, calendar, startsAt, offer.durationMinutes, now, {
        ownHoldKeyHash: holdKeyHash(input.holdKey)
      });
      if (!check.free) {
        return { status: 'slotTaken' as const, alternatives: check.alternatives.map(iso) };
      }

      for (const hold of previous) tx.delete(hold.snapshot.ref);
      const ref = refs(deps.db).hold(deps.random.uuid().replaceAll('-', '').slice(0, 20));
      const expiresAt = now + HOLD_MINUTES * 60_000;
      tx.set(ref, {
        ownerUid: calendar.ownerUid,
        slug: calendar.slug,
        serviceId: offer.serviceId,
        addOnIds: offer.addOns.map((addOn) => addOn.id),
        guests: offer.guests,
        startsAt: ts(startsAt),
        endsAt: ts(startsAt + offer.durationMinutes * 60_000),
        expiresAt: ts(expiresAt),
        holdKeyHash: holdKeyHash(input.holdKey),
        kind: 'soft'
      } satisfies HoldDoc);
      bumpCalendarLock(tx, deps.db, calendar.ownerUid);
      return { status: 'held' as const, holdId: ref.id, expiresAt: iso(expiresAt) };
    });
  }
});
