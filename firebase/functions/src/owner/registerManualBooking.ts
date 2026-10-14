import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { instantMs, iso } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import { ownerLinkToken, tokenHash, withNewTokenHash } from '../lib/bookingAccess.js';
import { emailHashOf, phoneHashOf } from '../lib/emailProof.js';
import { bumpCalendarLock, isOccupied, loadCalendar, loadOccupied, readCalendarLock, timingFields } from '../lib/calendar.js';
import { AppError } from '../lib/errors.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';
import type { AccountDoc, BookingDoc, PublicProfileDoc } from '../lib/docs.js';

/**
 * Registers an appointment created by the professional in the iPhone app, creating or updating an active `BookingDoc`
 * on the server with `phoneHash` and `emailHash`. Mints and returns the client's own manage link (`/m/<token>`).
 * Enables the client to confirm attendance, request reschedule/cancellation, and find their bookings via the web portal.
 */
export const registerManualBooking = defineUseCase({
  name: 'registerManualBooking',
  access: 'owner',
  ...contract.registerManualBooking,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'manageLinkOwner', uid, RATE.manageLinkOwner);
    const now = deps.now();
    const startsAtMs = instantMs(input.startsAt);
    const endsAtMs = instantMs(input.endsAt);
    if (endsAtMs <= startsAtMs) {
      throw new AppError('INVALID_ARGUMENT', { fields: ['endsAt'] });
    }
    const durationMinutes = Math.round((endsAtMs - startsAtMs) / 60_000);
    const timing = input.timing ?? { prepMinutes: 0, cleanupMinutes: 0, processingStartMinutes: 0, processingMinutes: 0 };
    if (input.serviceMinutes === undefined &&
      (input.serviceId !== undefined || input.addOns !== undefined || input.guestCount !== undefined || input.timing !== undefined)) {
      throw new AppError('INVALID_ARGUMENT', { fields: ['serviceMinutes'] });
    }
    if (input.serviceMinutes !== undefined &&
      input.serviceMinutes * (1 + (input.guestCount ?? 0)) +
      (input.addOns ?? []).reduce((total, addOn) => total + addOn.minutes, 0) !== durationMinutes) {
      throw new AppError('INVALID_ARGUMENT', { fields: ['endsAt'] });
    }
    if (timing.processingStartMinutes + timing.processingMinutes > durationMinutes ||
      (timing.processingMinutes === 0 && timing.processingStartMinutes !== 0) ||
      new Set((input.addOns ?? []).map((addOn) => addOn.id)).size !== (input.addOns ?? []).length) {
      throw new AppError('INVALID_ARGUMENT', { fields: ['timing', 'addOns'] });
    }

    const r = refs(deps.db);
    const accountDoc = dataOf<AccountDoc>(await r.account(uid).get());
    const slugName = accountDoc?.slug;
    if (!slugName) throw new AppError('NOT_FOUND');
    const profileDoc = dataOf<PublicProfileDoc>(await r.profile(slugName).get());
    if (!profileDoc) throw new AppError('NOT_FOUND');

    const bookingId = input.appointmentId.toLowerCase();
    const token = ownerLinkToken(deps.pepper, bookingId, now);
    const purgeAtMs = endsAtMs + 7 * 86_400_000;

    await runTransaction(deps.db, async (tx) => {
      const reader = txReader(tx);
      const bookingRef = r.booking(bookingId);
      const existing = dataOf<BookingDoc>(await reader.doc(bookingRef));
      if (existing && existing.ownerUid !== uid) throw new AppError('FORBIDDEN');
      const calendar = await loadCalendar(reader, deps.db, slugName);
      if (calendar?.ownerUid !== uid) throw new AppError('NOT_FOUND');
      await readCalendarLock(tx, deps.db, uid);
      const occupied = await loadOccupied(reader, deps.db, calendar,
        { start: startsAtMs - 86_400_000, end: endsAtMs + 86_400_000 }, now,
        { excludeBookingId: bookingId });
      if (isOccupied(occupied, startsAtMs, endsAtMs,
        { durationMinutes, timing },
        calendar.availability?.bufferMinutes ?? 0)) throw new AppError('CONFLICT');
      const phoneHash = phoneHashOf(deps.pepper, input.client.phone);
      const emailHash = input.client.email ? emailHashOf(deps.pepper, input.client.email) : undefined;
      const hashedToken = tokenHash(token);

      if (existing) {
        tx.update(bookingRef, {
          serviceName: input.serviceName,
          startsAt: ts(startsAtMs),
          endsAt: ts(endsAtMs),
          durationMinutes,
          serviceId: input.serviceId ?? existing.serviceId,
          addOns: input.addOns ?? existing.addOns,
          guestCount: input.guestCount ?? existing.guestCount,
          ...(input.timing ?? {}),
          timeZoneID: input.timeZoneID,
          'client.name': input.client.name,
          'client.phone': input.client.phone,
          ...(input.client.email ? { 'client.email': input.client.email } : {}),
          ...(input.client.locale ? { 'client.locale': input.client.locale } : {}),
          phoneHash,
          ...(emailHash ? { emailHash } : {}),
          manageTokenHashes: withNewTokenHash(existing.manageTokenHashes, hashedToken),
          ownerLinkMintedAt: ts(now),
          updatedAt: ts(now),
          purgeAt: ts(purgeAtMs)
        });
      } else {
        const doc: BookingDoc = {
          schemaVersion: 1,
          ownerUid: uid,
          slug: slugName,
          status: 'confirmed',
          serviceId: input.serviceId ?? 'manual',
          serviceName: input.serviceName,
          durationMinutes,
          addOns: input.addOns ?? [],
          guestCount: input.guestCount ?? 0,
          ...timingFields(timing),
          startsAt: ts(startsAtMs),
          endsAt: ts(endsAtMs),
          timeZoneID: input.timeZoneID,
          client: {
            name: input.client.name,
            phone: input.client.phone,
            ...(input.client.email ? { email: input.client.email } : {}),
            locale: input.client.locale ?? 'pt-BR'
          },
          phoneHash,
          ...(emailHash ? { emailHash } : {}),
          manageTokenHashes: [hashedToken],
          origin: 'manual',
          policy: profileDoc.policy,
          rulesText: profileDoc.rulesText,
          noShowPolicy: {
            isOn: calendar.availability?.noShow.isOn ?? false,
            limit: calendar.availability?.noShow.limit ?? 3,
            lateCancelCounts: calendar.availability?.noShow.lateCancelCounts ?? false
          },
          rescheduleCount: 0,
          ownerLinkMintedAt: ts(now),
          createdAt: ts(now),
          updatedAt: ts(now),
          purgeAt: ts(purgeAtMs)
        };
        tx.set(bookingRef, doc);
      }
      bumpCalendarLock(tx, deps.db, uid);
    });

    deps.log.info('manualBooking.registered', { uid, bookingId });
    return {
      bookingId,
      url: `${deps.settings.webBaseUrl}/m/${token}`,
      expiresAt: iso(purgeAtMs)
    };
  }
});
