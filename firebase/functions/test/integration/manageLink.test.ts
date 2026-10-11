import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { MAX_MANAGE_TOKENS_PER_BOOKING, RATE } from '../../src/config/limits.js';
import { tokenHash } from '../../src/lib/bookingAccess.js';
import { refs } from '../../src/lib/store.js';
import { cancelBookingByOwner } from '../../src/owner/cancelBookingByOwner.js';
import { mintManageLink } from '../../src/owner/mintManageLink.js';
import { getBooking } from '../../src/token/getBooking.js';
import { ANA, asBooked, book, bookingDoc } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { captureWorld, ownerContext, restoreWorld, seedProfessional } from '../support/seed.js';
import type { Professional, World } from '../support/seed.js';

// mintManageLink (API.md 6.3): the client's own link to change or cancel, for the message the professional sends from
// the app. Same token machinery as the booking's other links: hashed at rest, at most five valid.
const env = createTestEnv();
let pro: Professional;
let world: World;
const MINUTE = 60_000;

beforeAll(async () => {
  await resetEmulators(env);
  pro = await seedProfessional(env);
  world = await captureWorld(env, pro);
});

beforeEach(async () => {
  await resetEmulators(env);
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  env.logs.entries.length = 0;
  await restoreWorld(env, world);
});

const owner = () => ownerContext(pro.uid);

interface Minted {
  url: string;
  expiresAt: string;
}

async function mint(bookingId: string, context = owner()): Promise<Minted> {
  return (await env.call(mintManageLink, { bookingId }, context)) as Minted;
}

function tokenOf(url: string): string {
  const match = /^https:\/\/bellohub\.test\/m\/([A-Za-z0-9_-]{22})$/.exec(url);
  if (!match?.[1]) throw new Error(`not a manage link: ${url}`);
  return match[1];
}

describe('mintManageLink', () => {
  it('returns a full link that opens the booking, stores only its hash and ends with the token', async () => {
    const booked = asBooked(await book(env, pro));

    const minted = await mint(booked.bookingId);

    const token = tokenOf(minted.url);
    const stored = await bookingDoc(env, booked.bookingId);
    expect(stored.manageTokenHashes).toContain(tokenHash(token));
    expect(JSON.stringify(stored)).not.toContain(token);
    expect(stored.ownerLinkMintedAt).toBeDefined();
    expect(Date.parse(minted.expiresAt)).toBe(stored.purgeAt.toMillis());
    const opened = (await env.call(getBooking, { token })) as { bookingId: string; status: string };
    expect(opened).toMatchObject({ bookingId: booked.bookingId, status: 'confirmed' });
    // The client's earlier link keeps working.
    expect(await env.call(getBooking, { token: booked.manageToken })).toMatchObject({ bookingId: booked.bookingId });
  });

  it('is idempotent for 30 minutes: the same link, no extra token; after that a new one', async () => {
    const booked = asBooked(await book(env, pro));
    const first = await mint(booked.bookingId);
    env.clock.advance(29 * MINUTE);

    const again = await mint(booked.bookingId);

    expect(again.url).toBe(first.url);
    expect((await bookingDoc(env, booked.bookingId)).manageTokenHashes).toHaveLength(2);
    env.clock.advance(2 * MINUTE);
    const later = await mint(booked.bookingId);
    expect(later.url).not.toBe(first.url);
    expect((await bookingDoc(env, booked.bookingId)).manageTokenHashes).toHaveLength(3);
    // The first link still opens the booking: nothing was dropped yet.
    expect(await env.call(getBooking, { token: tokenOf(first.url) })).toMatchObject({ bookingId: booked.bookingId });
  });

  it('keeps at most five valid links per booking, dropping the oldest', async () => {
    const booked = asBooked(await book(env, pro));
    const urls: string[] = [];
    for (let index = 0; index < MAX_MANAGE_TOKENS_PER_BOOKING; index += 1) {
      urls.push((await mint(booked.bookingId)).url);
      env.clock.advance(31 * MINUTE);
    }

    const stored = await bookingDoc(env, booked.bookingId);
    expect(stored.manageTokenHashes).toHaveLength(MAX_MANAGE_TOKENS_PER_BOOKING);
    expect(stored.manageTokenHashes).not.toContain(tokenHash(booked.manageToken));
    await expect(env.call(getBooking, { token: booked.manageToken })).rejects.toMatchObject({ code: 'NOT_FOUND' });
    for (const url of urls) {
      expect(await env.call(getBooking, { token: tokenOf(url) })).toMatchObject({ bookingId: booked.bookingId });
    }
  });

  it('mints a new link inside the window when five newer links pushed the reused one out', async () => {
    const booked = asBooked(await book(env, pro));
    const first = await mint(booked.bookingId);
    const ref = refs(env.deps.db).booking(booked.bookingId);
    await ref.update({ manageTokenHashes: ['a', 'b', 'c', 'd', 'e'] });
    env.clock.advance(MINUTE);

    const again = await mint(booked.bookingId);

    expect(again.url).not.toBe(first.url);
    expect((await bookingDoc(env, booked.bookingId)).manageTokenHashes).toContain(tokenHash(tokenOf(again.url)));
    await expect(env.call(getBooking, { token: tokenOf(first.url) })).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it("answers NOT_FOUND for someone else's booking, so ids cannot be probed", async () => {
    const booked = asBooked(await book(env, pro));

    await expect(mint(booked.bookingId, ownerContext('someone-else'))).rejects.toMatchObject({ code: 'NOT_FOUND' });
    await expect(mint('no-such-booking')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('refuses a cancelled or finished visit (BOOKING_NOT_ACTIVE): the app then uses her booking page', async () => {
    const cancelled = asBooked(await book(env, pro));
    await env.call(cancelBookingByOwner, { bookingId: cancelled.bookingId }, owner());
    await expect(mint(cancelled.bookingId)).rejects.toMatchObject({ code: 'BOOKING_NOT_ACTIVE' });

    const past = asBooked(await book(env, pro, { client: { ...ANA, phone: '+5511912345678' }, startsAt: '2026-10-02T17:00:00.000Z' }));
    env.clock.set(Date.parse(past.endsAt));
    await expect(mint(past.bookingId)).rejects.toMatchObject({ code: 'BOOKING_NOT_ACTIVE' });
  });

  it('is limited per professional and needs a signed-in owner', async () => {
    const booked = asBooked(await book(env, pro));
    await expect(env.call(mintManageLink, { bookingId: booked.bookingId })).rejects.toMatchObject({ code: 'UNAUTHENTICATED' });
    for (let index = 0; index < RATE.manageLinkOwner.limit; index += 1) await mint(booked.bookingId);

    await expect(mint(booked.bookingId)).rejects.toMatchObject({ code: 'RATE_LIMITED' });
  });

  it('logs ids only: never the token, the link or anything about the client', async () => {
    const booked = asBooked(await book(env, pro, { client: { ...ANA, email: 'ana@example.com' } }));
    env.logs.entries.length = 0;

    const minted = await mint(booked.bookingId);
    await mint(booked.bookingId);

    const logged = JSON.stringify(env.logs.entries);
    expect(env.logs.entries.filter((entry) => entry.event === 'manageLink.minted')).toHaveLength(2);
    expect(logged).not.toContain(tokenOf(minted.url));
    expect(logged).not.toContain('/m/');
    expect(logged).not.toContain(ANA.phone);
    expect(logged).not.toContain('ana@example.com');
    expect(logged).not.toContain(ANA.name);
  });
});
