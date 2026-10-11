import { beforeEach, describe, expect, it } from 'vitest';

import type { PublicProfileInput } from '../../src/contracts/profile.js';
import { handleIcs } from '../../src/http/icsHandler.js';
import type { BusinessLocationDoc, PublicProfileDoc } from '../../src/lib/docs.js';
import { refs } from '../../src/lib/store.js';
import { moveBookingByOwner } from '../../src/owner/moveBookingByOwner.js';
import { publishProfile } from '../../src/owner/publishProfile.js';
import { respondBookingRequest } from '../../src/owner/respondBookingRequest.js';
import { getPublicPage } from '../../src/public/getPublicPage.js';
import { getBooking } from '../../src/token/getBooking.js';
import { ANA, asBooked, book } from '../support/booking.js';
import { createTestEnv, resetEmulators } from '../support/env.js';
import { mariaProfile, ownerContext, seedProfessional } from '../support/seed.js';
import type { Professional } from '../support/seed.js';

// Where she works (owner, 2026-10-11): stored apart from the world-readable page, shown to a confirmed booking (the
// default) or also on the page, and carried by the e-mails and the calendar file.
const env = createTestEnv();
let pro: Professional;
const who = () => ownerContext(pro.uid);

const LOCATION = {
  lines: ['Rua Augusta 1200', 'São Paulo 01304-001'],
  directions: '2º andar, interfone 4',
  maps: {
    apple: 'https://maps.apple.com/?address=Rua%20Augusta%201200%2C%20S%C3%A3o%20Paulo%2001304-001%2C%20Brazil',
    google: 'https://www.google.com/maps/search/?api=1&query=Rua%20Augusta%201200%2C%20S%C3%A3o%20Paulo%2001304-001%2C%20Brazil'
  }
};

async function publish(location?: PublicProfileInput['location'], overrides: Partial<PublicProfileInput> = {}): Promise<void> {
  await env.call(publishProfile, { profile: { ...mariaProfile(pro.inboxKey, overrides), ...(location ? { location } : {}) } }, who());
}

async function stored(): Promise<BusinessLocationDoc | undefined> {
  return (await refs(env.deps.db).businessLocation(pro.uid).get()).data() as BusinessLocationDoc | undefined;
}

async function page(): Promise<PublicProfileDoc> {
  return (await refs(env.deps.db).profile(pro.slug).get()).data() as PublicProfileDoc;
}

beforeEach(async () => {
  await resetEmulators(env);
  env.clock.set(Date.UTC(2026, 9, 1, 15, 0));
  env.mail.sent.length = 0;
  pro = await seedProfessional(env);
});

describe('publishing the address', () => {
  it('keeps a confirmed-only address out of the world-readable page', async () => {
    await publish({ ...LOCATION, visibility: 'confirmed' });

    expect(await stored()).toMatchObject({ ownerUid: pro.uid, location: LOCATION, visibility: 'confirmed' });
    expect((await page()).location).toBeUndefined();
    const served = (await env.call(getPublicPage, { slug: pro.slug })) as { profile: Record<string, unknown> };
    expect(served.profile).not.toHaveProperty('location');
  });

  it('puts a public address on the page, without saying who may see it', async () => {
    await publish({ ...LOCATION, visibility: 'public' });

    const served = (await env.call(getPublicPage, { slug: pro.slug })) as { profile: { location?: unknown } };
    expect(served.profile.location).toEqual(LOCATION);
    expect((await page()).location).not.toHaveProperty('visibility');
  });

  it('removes it everywhere when she publishes without one, or switches back to confirmed only', async () => {
    await publish({ ...LOCATION, visibility: 'public' });
    await publish({ ...LOCATION, visibility: 'confirmed' });
    expect((await page()).location).toBeUndefined();

    await publish();
    expect(await stored()).toBeUndefined();
    expect((await page()).location).toBeUndefined();
  });

  it('refuses a map link to anywhere else, or an empty address', async () => {
    const elsewhere = { ...LOCATION, maps: { ...LOCATION.maps, google: 'https://evil.example/maps?q=x' }, visibility: 'confirmed' as const };
    await expect(publish(elsewhere)).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
    await expect(publish({ ...LOCATION, lines: [], visibility: 'confirmed' })).rejects.toMatchObject({ code: 'INVALID_ARGUMENT' });
  });
});

describe('who sees it', () => {
  it('a confirmed booking gets it on its page; a request still waiting does not, unless it is public', async () => {
    await publish({ ...LOCATION, visibility: 'confirmed' });
    const confirmed = asBooked(await book(env, pro));
    expect(await env.call(getBooking, { token: confirmed.manageToken })).toMatchObject({ location: LOCATION });

    await refs(env.deps.db).profile(pro.slug).update({ 'booking.requiresApproval': true });
    const pending = asBooked(await book(env, pro, { client: { ...ANA, phone: '+5511912345678' }, startsAt: '2026-10-02T17:00:00.000Z' }));
    expect(pending.status).toBe('pendingApproval');
    expect(await env.call(getBooking, { token: pending.manageToken })).not.toHaveProperty('location');

    await publish({ ...LOCATION, visibility: 'public' }, { booking: { ...mariaProfile(pro.inboxKey).booking, requiresApproval: true } });
    expect(await env.call(getBooking, { token: pending.manageToken })).toMatchObject({ location: LOCATION });
  });

  it('nothing is shown when she never saved an address', async () => {
    const confirmed = asBooked(await book(env, pro));
    expect(await env.call(getBooking, { token: confirmed.manageToken })).not.toHaveProperty('location');
  });
});

describe('e-mails and the calendar file', () => {
  it('the confirmation e-mail says where, with both map links, and shows the personal link as a button', async () => {
    await publish({ ...LOCATION, visibility: 'confirmed' });
    const booked = asBooked(await book(env, pro, { client: { ...ANA, email: 'ana@example.com' } }));

    const mail = env.mail.sent[0];
    expect(mail?.text).toContain(`Onde\nRua Augusta 1200\nSão Paulo 01304-001\n2º andar, interfone 4\nMapas da Apple:\n${LOCATION.maps.apple}`);
    expect(mail?.text).toContain(`\n${env.deps.settings.webBaseUrl}/m/${booked.manageToken}\n`);
    expect(mail?.html).toContain('>Remarcar ou cancelar</a>');
    expect(mail?.html).toContain(`href="${LOCATION.maps.google.replaceAll('&', '&amp;')}"`);
  });

  it('a request waiting for her is not told a confirmed-only address', async () => {
    await publish({ ...LOCATION, visibility: 'confirmed' }, { booking: { ...mariaProfile(pro.inboxKey).booking, requiresApproval: true } });
    await book(env, pro, { client: { ...ANA, email: 'ana@example.com' } });

    expect(env.mail.sent[0]?.text).not.toContain('Rua Augusta');
  });

  it('the approval and the move e-mails carry a fresh personal link that opens the booking, and the address', async () => {
    await publish({ ...LOCATION, visibility: 'confirmed' }, { booking: { ...mariaProfile(pro.inboxKey).booking, requiresApproval: true } });
    const request = asBooked(await book(env, pro, { client: { ...ANA, email: 'ana@example.com' } }));
    env.mail.sent.length = 0;

    await env.call(respondBookingRequest, { bookingId: request.bookingId, decision: 'approve' }, who());
    const approved = env.mail.sent[0]?.text ?? '';
    const approvedToken = /\/m\/([A-Za-z0-9_-]{22})/.exec(approved)?.[1] ?? '';
    expect(approved).toContain('Rua Augusta 1200');
    expect(await env.call(getBooking, { token: approvedToken })).toMatchObject({ bookingId: request.bookingId, status: 'confirmed' });

    env.mail.sent.length = 0;
    await env.call(moveBookingByOwner, { bookingId: request.bookingId, startsAt: '2026-10-02T18:00:00.000Z' }, who());
    const moved = env.mail.sent[0]?.text ?? '';
    const movedToken = /\/m\/([A-Za-z0-9_-]{22})/.exec(moved)?.[1] ?? '';
    expect(moved).toContain('Rua Augusta 1200');
    expect(movedToken).not.toBe(approvedToken);
    expect(await env.call(getBooking, { token: movedToken })).toMatchObject({ bookingId: request.bookingId });
  });

  it('the calendar file has the address and the map, and her page instead of the manage link (D50)', async () => {
    await publish({ ...LOCATION, visibility: 'confirmed' });
    const booked = asBooked(await book(env, pro));

    const ics = await handleIcs(env.deps, { token: booked.manageToken }, 'ip-hash');
    const unfolded = ics.body.replace(/\r\n /g, '');

    expect(ics.status).toBe(200);
    expect(unfolded).toContain('LOCATION:Rua Augusta 1200\\, São Paulo 01304-001');
    expect(unfolded).toContain(LOCATION.maps.google);
    expect(unfolded).toContain(`URL:${env.deps.settings.webBaseUrl}/${pro.slug}`);
    expect(unfolded).not.toContain(booked.manageToken);
  });
});
