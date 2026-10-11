import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import type { AppError } from '../../src/lib/errors.js';
import { refs } from '../../src/lib/store.js';
import { ProviderClientMessenger } from '../../src/messaging/ProviderClientMessenger.js';
import { findBookings } from '../../src/public/findBookings.js';
import { sendEmailCode } from '../../src/public/sendEmailCode.js';
import { verifyEmailCode } from '../../src/public/verifyEmailCode.js';
import { ANA, asBooked, book } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { captureWorld, FRIDAY_10, restoreWorld, seedProfessional } from '../support/seed.js';
import type { Professional, World } from '../support/seed.js';

const env = createTestEnv();
let pro: Professional;
let world: World;

beforeAll(async () => {
  await resetEmulators(env);
  pro = await seedProfessional(env);
  world = await captureWorld(env, pro);
});

beforeEach(async () => {
  await resetEmulators(env);
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  env.mail.sent.length = 0;
  await restoreWorld(env, world);
});

const EMAIL = 'ana@example.com';

/** The six digits of the last verification email. */
function lastCode(): string {
  const text = env.mail.sent.at(-1)?.text ?? '';
  const code = /\b(\d{6})\b/.exec(text)?.[1];
  if (!code) throw new Error('no code in the email');
  return code;
}

async function send(email = EMAIL, purpose: 'booking' | 'find' = 'booking') {
  return env.call(sendEmailCode, { slug: pro.slug, email, locale: 'pt-BR', purpose });
}

async function verify(code: string, email = EMAIL) {
  return (await env.call(verifyEmailCode, { email, code })) as { proof: string; expiresInSeconds: number };
}

describe('sendEmailCode', () => {
  it('emails a six digit code that is stored only as a hash and expires in ten minutes', async () => {
    const result = await send();

    expect(result).toEqual({ resendAfterSeconds: 30, expiresInSeconds: 1800 });
    expect(env.mail.sent).toHaveLength(1);
    expect(env.mail.sent[0]?.to).toBe(EMAIL);
    expect(env.mail.sent[0]?.subject).toContain(lastCode());
    const stored = await env.deps.db.collection('emailCodes').get();
    expect(stored.size).toBe(1);
    expect(JSON.stringify(stored.docs[0]?.data())).not.toContain(lastCode());
    expect(JSON.stringify(stored.docs[0]?.data())).not.toContain(EMAIL);
  });

  it('makes the resend wait thirty seconds and says how long', async () => {
    await send();

    const error = (await send().catch((caught: unknown) => caught)) as AppError;
    expect(error.code).toBe('RATE_LIMITED');
    expect(error.details?.retryAfterSeconds).toBe(30);

    env.clock.advance(31_000);
    await send();
    expect(env.mail.sent).toHaveLength(2);
  });

  it('writes the email in the language of the page visitor', async () => {
    await env.call(sendEmailCode, { slug: pro.slug, email: EMAIL, locale: 'de', purpose: 'booking' });

    expect(env.mail.sent[0]?.subject).toMatch(/Bestätigungscode/);
  });

  it('limits one address to five codes an hour', async () => {
    for (let n = 0; n < 5; n += 1) {
      await send();
      env.clock.advance(31_000);
    }

    await expect(send()).rejects.toMatchObject({ code: 'RATE_LIMITED' });
  });

  it('limits one caller (IP) to ten codes an hour across addresses, and one professional to a daily cap (D46)', async () => {
    for (let n = 0; n < 10; n += 1) await send(`visitor${n}@example.com`);

    await expect(send('visitor10@example.com')).rejects.toMatchObject({ code: 'RATE_LIMITED', details: { retryAfterSeconds: expect.any(Number) as number } });
    // Another caller is not affected.
    expect(await env.call(sendEmailCode, { slug: pro.slug, email: 'visitor10@example.com', locale: 'pt-BR', purpose: 'booking' }, { ip: '198.51.100.9' })).toMatchObject({ resendAfterSeconds: 30 });
  });

  it('is NOT_CONFIGURED where no email provider exists, and keeps no code behind', async () => {
    const original = env.deps.messenger;
    env.deps.messenger = new ProviderClientMessenger(env.mail, env.whatsapp, false);
    try {
      await expect(send()).rejects.toMatchObject({ code: 'NOT_CONFIGURED' });
      expect((await env.deps.db.collection('emailCodes').get()).size).toBe(0);
    } finally {
      env.deps.messenger = original;
    }
  });

  it('removes the code when the email cannot be sent', async () => {
    env.mail.failNext = true;

    await expect(send()).rejects.toThrow();
    expect((await env.deps.db.collection('emailCodes').get()).size).toBe(0);
  });

  it('answers NOT_FOUND for an unknown page', async () => {
    await expect(env.call(sendEmailCode, { slug: 'nobody', email: EMAIL, locale: 'en', purpose: 'booking' })).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('verifyEmailCode', () => {
  it('turns the right code into a single-use proof', async () => {
    await send();

    const result = await verify(lastCode());

    expect(result.expiresInSeconds).toBe(1800);
    expect(result.proof).toMatch(/^[A-Za-z0-9_-]{22}$/);
    await expect(verify(lastCode())).rejects.toMatchObject({ code: 'INVALID_CODE' });
  });

  it('refuses a wrong code, a code for another address and an expired code', async () => {
    await send();
    const code = lastCode();

    await expect(verify(code === '000000' ? '111111' : '000000')).rejects.toMatchObject({ code: 'INVALID_CODE' });
    await expect(verify(code, 'someone@else.com')).rejects.toMatchObject({ code: 'INVALID_CODE' });
    env.clock.advance(601_000);
    await expect(verify(code)).rejects.toMatchObject({ code: 'INVALID_CODE' });
  });

  it('invalidates the code after five wrong tries, even for the right code', async () => {
    await send();
    const code = lastCode();
    const wrong = code === '000000' ? '111111' : '000000';
    for (let n = 0; n < 5; n += 1) await verify(wrong).catch(() => undefined);

    await expect(verify(code)).rejects.toMatchObject({ code: 'INVALID_CODE' });
  });

  it('never stores the proof in the clear', async () => {
    await send();
    const { proof } = await verify(lastCode());

    const proofs = await env.deps.db.collection('emailProofs').get();
    expect(proofs.size).toBe(1);
    expect(JSON.stringify(proofs.docs[0]?.data())).not.toContain(proof);
    expect(proofs.docs[0]?.id).not.toContain(proof);
  });
});

describe('booking with an email proof', () => {
  async function proofFor(email: string): Promise<string> {
    await send(email);
    return (await verify(lastCode(), email)).proof;
  }

  it('books with a verified email and consumes the proof', async () => {
    const proof = await proofFor(EMAIL);
    const client = { ...ANA, email: EMAIL };

    const first = asBooked(await book(env, pro, { client, verification: { method: 'email', proof } }));
    expect(first.status).toBe('confirmed');

    const reused = await book(env, pro, { client, startsAt: '2026-10-02T17:00:00.000Z', verification: { method: 'email', proof } }).catch((caught: unknown) => caught);
    expect((reused as AppError).code).toBe('VERIFICATION_FAILED');
  });

  it('keeps the proof when the time was taken, so the client can pick another time', async () => {
    const proof = await proofFor(EMAIL);
    asBooked(await book(env, pro, { client: { ...ANA, phone: '+5511976543210' } }));

    const taken = await book(env, pro, { client: { ...ANA, email: EMAIL }, verification: { method: 'email', proof } });
    expect(taken.status).toBe('slotTaken');
    const retry = await book(env, pro, { client: { ...ANA, email: EMAIL }, startsAt: '2026-10-02T17:00:00.000Z', verification: { method: 'email', proof } });
    expect(retry.status).toBe('confirmed');
  });

  it('refuses a proof for another address and a booking without an email', async () => {
    const proof = await proofFor(EMAIL);

    await expect(book(env, pro, { client: { ...ANA, email: 'other@example.com' }, verification: { method: 'email', proof } })).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
    await expect(book(env, pro, { verification: { method: 'email', proof } })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });

  it('refuses an expired proof', async () => {
    const proof = await proofFor(EMAIL);
    env.clock.advance(31 * 60_000);

    await expect(book(env, pro, { client: { ...ANA, email: EMAIL }, verification: { method: 'email', proof } })).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
  });
});

describe('findBookings', () => {
  it('lists the upcoming bookings of a verified phone with a fresh link each, and keeps the old links working', async () => {
    const first = asBooked(await book(env, pro, { startsAt: FRIDAY_10 }));
    asBooked(await book(env, pro, { startsAt: '2026-10-02T17:00:00.000Z' }));

    const found = (await env.call(findBookings, {
      slug: pro.slug,
      phone: ANA.phone,
      verification: { method: 'phone', idToken: env.phoneToken(ANA.phone) }
    })) as { bookings: { bookingId: string; manageToken: string; startsAt: string; status: string }[] };

    expect(found.bookings.map((booking) => booking.startsAt)).toEqual([FRIDAY_10, '2026-10-02T17:00:00.000Z']);
    expect(found.bookings[0]?.bookingId).toBe(first.bookingId);
    expect(found.bookings[0]?.manageToken).not.toBe(first.manageToken);
    const stored = (await refs(env.deps.db).booking(first.bookingId).get()).data() as { manageTokenHashes: string[] };
    expect(stored.manageTokenHashes).toHaveLength(2);
  });

  it('returns an empty list, not an error, for a phone with no bookings', async () => {
    asBooked(await book(env, pro));

    const found = await env.call(findBookings, {
      slug: pro.slug,
      phone: '+5511900009999',
      verification: { method: 'phone', idToken: env.phoneToken('+5511900009999') }
    });

    expect(found).toEqual({ bookings: [] });
  });

  it('does not list past or cancelled bookings, or bookings of another professional', async () => {
    const booked = asBooked(await book(env, pro, { startsAt: FRIDAY_10 }));
    await refs(env.deps.db).booking(booked.bookingId).update({ status: 'cancelledByClient' });
    const other = await seedProfessional(env, { uid: 'pro-other', slug: 'other-pro' });
    asBooked(await book(env, other, { slug: other.slug, startsAt: FRIDAY_10 }));

    const found = (await env.call(findBookings, {
      slug: pro.slug,
      phone: ANA.phone,
      verification: { method: 'phone', idToken: env.phoneToken(ANA.phone) }
    })) as { bookings: unknown[] };

    expect(found.bookings).toEqual([]);
  });

  it('works with a verified email', async () => {
    const proof0 = await (async () => {
      await send();
      return (await verify(lastCode())).proof;
    })();
    asBooked(await book(env, pro, { client: { ...ANA, email: EMAIL }, verification: { method: 'email', proof: proof0 } }));
    env.clock.advance(31_000);
    await send(EMAIL, 'find');
    const proof = (await verify(lastCode())).proof;

    const found = (await env.call(findBookings, { slug: pro.slug, email: EMAIL, verification: { method: 'email', proof } })) as { bookings: unknown[] };

    expect(found.bookings).toHaveLength(1);
  });

  it('refuses a phone token for another number and requires the phone to be sent', async () => {
    await expect(
      env.call(findBookings, { slug: pro.slug, phone: ANA.phone, verification: { method: 'phone', idToken: env.phoneToken('+5511900009999') } })
    ).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
    await expect(
      env.call(findBookings, { slug: pro.slug, verification: { method: 'phone', idToken: env.phoneToken(ANA.phone) } })
    ).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });
});
