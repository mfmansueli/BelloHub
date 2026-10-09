import { defineUseCase } from '../app/UseCase.js';
import { MAX_SEALED_PER_BOOKING, RATE, SIZE } from '../config/limits.js';
import * as contract from '../contracts/public.js';
import { findBookingByToken, tokenHash } from '../lib/bookingAccess.js';
import { writeContact } from '../lib/contacts.js';
import { base64urlByteLength, sha256Hex } from '../lib/crypto.js';
import type { AccountDoc, ContactDoc, InboxItemDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { isKnownKey } from '../lib/keyring.js';
import { consumeRates } from '../lib/rateLimit.js';
import { envelopeExpiresAt } from '../lib/rules.js';
import { dataOf, plainReader, refs, ts, txReader } from '../lib/store.js';
import { runTransaction } from '../lib/tx.js';

const PLAINTEXT_CAP = { intake: SIZE.intakeBytes, checkin: SIZE.checkinBytes, datarequest: SIZE.dataRequestBytes } as const;

/**
 * The sealed mailbox, client side (docs/06 section 3.5): stores an opaque envelope and nothing else. The server checks
 * who may send (a valid link), where it goes (a key the professional really holds), how big it is, and how often; it never
 * opens the envelope and never logs it. Expires after 30 days unless the app acknowledges it first (D30).
 */
export const submitSealed = defineUseCase({
  name: 'submitSealed',
  access: 'token',
  ...contract.submitSealed,
  async handle(deps, input, ctx) {
    const { envelope } = input;
    await consumeRates(deps, [
      { scope: 'sealedBooking', subject: tokenHash(input.token), rate: RATE.sealedBooking },
      { scope: 'sealedIp', subject: ctx.ipHash, rate: RATE.sealedIp }
    ]);

    const sizeBytes = base64urlByteLength(envelope.ct);
    const cap = PLAINTEXT_CAP[envelope.kind] + SIZE.envelopeSlackBytes;
    if (sizeBytes > cap) throw new AppError('PAYLOAD_TOO_LARGE', { maxBytes: cap });

    const now = deps.now();
    const r = refs(deps.db);
    const booking = await findBookingByToken(plainReader, deps.db, input.token, now);
    // A form for a visit that was cancelled or declined makes no sense; a data request is allowed whatever happened.
    if (envelope.kind !== 'datarequest' && ['cancelledByClient', 'cancelledByPro', 'declined'].includes(booking.data.status)) {
      throw new AppError('BOOKING_NOT_ACTIVE', { status: booking.data.status });
    }
    const ownerUid = booking.data.ownerUid;
    const account = dataOf<AccountDoc>(await r.account(ownerUid).get());
    if (!account || !isKnownKey(account.inboxKeyring, envelope.keyId)) throw new AppError('KEY_MISMATCH');

    const ctHash = sha256Hex(envelope.ct);
    const itemRef = r.inboxItem(ownerUid, envelope.itemId);
    const existing = dataOf<InboxItemDoc>(await itemRef.get());
    if (existing) {
      // A retry of the same envelope is a success; a different ciphertext under the same id is never accepted.
      if (existing.ctHash === ctHash) return { ok: true as const };
      throw new AppError('CONFLICT');
    }
    // One link cannot fill her mailbox: past the cap the client waits for the app to collect (checked again in the
    // transaction, before the Storage object is paid for here).
    const unacknowledged = r.inboxItems(ownerUid).where('bookingId', '==', booking.id).select();
    if ((await unacknowledged.get()).size >= MAX_SEALED_PER_BOOKING) throw new AppError('RATE_LIMITED', { maxItems: MAX_SEALED_PER_BOOKING });

    const inline = sizeBytes <= SIZE.inlineBytes;
    // The object name carries the ciphertext hash: two different envelopes racing under one item id get two objects,
    // so the loser's clean-up can never remove the winner's bytes.
    const storagePath = `inbox/${ownerUid}/${envelope.itemId}.${ctHash.slice(0, 16)}.json`;
    if (!inline) await deps.blobs.put(storagePath, Buffer.from(JSON.stringify(envelope), 'utf8'), 'application/json');

    const item: InboxItemDoc = {
      ownerUid,
      bookingId: booking.id,
      kind: envelope.kind,
      keyId: envelope.keyId,
      sizeBytes,
      ctHash,
      createdAt: ts(now),
      expiresAt: ts(envelopeExpiresAt(now)),
      ...(inline ? { envelope } : { storagePath })
    };
    try {
      await runTransaction(deps.db, async (tx) => {
        const reader = txReader(tx);
        const again = await reader.doc(itemRef);
        if (again.exists) throw new AppError('CONFLICT');
        if ((await reader.query(unacknowledged)).size >= MAX_SEALED_PER_BOOKING) {
          throw new AppError('RATE_LIMITED', { maxItems: MAX_SEALED_PER_BOOKING });
        }
        const contact = dataOf<ContactDoc>(await reader.doc(r.contact(ownerUid, booking.data.phoneHash)));
        tx.create(itemRef, item);
        if (envelope.kind === 'intake') {
          tx.update(booking.ref, { intakeSubmittedAt: ts(now), updatedAt: ts(now) });
          writeContact(tx, r, ownerUid, booking.data.phoneHash, contact, { lastIntakeAt: ts(now) }, now);
        }
      });
    } catch (error) {
      if (error instanceof AppError && error.code === 'CONFLICT') {
        // The same envelope was stored by a parallel retry: it owns the Storage object, so leave it alone.
        const winner = dataOf<InboxItemDoc>(await itemRef.get());
        if (winner?.ctHash === ctHash) return { ok: true as const };
      }
      if (!inline) await deps.blobs.delete(storagePath);
      throw error;
    }
    deps.log.info('sealed.stored', { ownerUid, itemId: envelope.itemId, kind: envelope.kind, sizeBytes });
    return { ok: true as const };
  }
});
