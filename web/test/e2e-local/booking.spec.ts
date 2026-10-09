// One client's story against the real backend (S8 exit criterion, docs/03): Maria published her page and her hours
// (firebase/functions/scripts/seed.ts, through the owner API), Helena books from the page served by the Hosting
// emulator, moves the visit, sends her sealed health form, cancels, and the emulator's outbox shows what Maria's
// iPhone and Helena's inbox would have received. Every call goes through the /api rewrites of firebase/firebase.json.
//
// The verification is by email (the emulator's fixed code): the production phone verifier runs in the browser
// through Firebase Auth, which the page's CSP (`connect-src 'self'`) keeps from reaching the Auth emulator's origin.

import { chooseDayAhead, expect, open, tap, test, waitFor, type SeenRequest } from './support';

const UID = 'demo-maria';
const SLUG = 'maria';
const ZONE = 'America/Sao_Paulo';
const EMAIL_CODE = '123456';
const CLIENT = { name: 'Helena Duarte', phone: '11 98765 4321', email: 'helena@example.com' } as const;
const SECRET = 'SECRET-ANSWER-7f3a91';

interface Envelope {
  v: number;
  suite: string;
  keyId: string;
  kind: string;
  itemId: string;
  enc: string;
  ct: string;
}

/** The story's state, carried from one test to the next (serial mode, one worker). */
const story: { token: string; bookingId: string; startsAt: string; movedTo: string; envelope: Envelope | null } = {
  token: '',
  bookingId: '',
  startsAt: '',
  movedTo: '',
  envelope: null,
};

function apiCalls(requests: SeenRequest[], name: string): SeenRequest[] {
  return requests.filter((request) => request.method === 'POST' && new URL(request.url).pathname === `/api/${name}`);
}

test.describe.configure({ mode: 'serial' });

test.describe('a client and the real functions', () => {
  test('Maria is published: her page comes from the functions through /api', async ({ page, requests, store }) => {
    await open(page, `/${SLUG}`);
    await expect(page.getByTestId('services')).toBeVisible();
    await expect(page.locator('[data-testid^="service-"]').first()).toBeVisible();
    expect(apiCalls(requests, 'getPublicPage')).toHaveLength(1);
    expect(await store.bookings()).toEqual([]);
  });

  test('Helena books a time more than a day ahead, verified by email, and gets her personal link', async ({ page, requests, store }) => {
    await open(page, `/${SLUG}`);
    await page.locator('[data-testid^="service-"]').first().click();
    await page.getByTestId('continue').click();

    // A day at least two days out: inside the free window, so the later move and cancellation are direct and free.
    await chooseDayAhead(page, ZONE, 2);
    const slots = page.locator('[data-testid^="slot-"]');
    await expect(slots.first()).toBeVisible();
    story.startsAt = ((await slots.first().getAttribute('data-testid')) ?? '').replace('slot-', '');
    await slots.first().click();
    await page.getByTestId('continue').click();
    expect(apiCalls(requests, 'holdSlot')).toHaveLength(1);

    await expect(page.getByTestId('name')).toBeVisible();
    await page.getByTestId('name').fill(CLIENT.name);
    await page.getByTestId('phone').fill(CLIENT.phone);
    await page.getByTestId('email').fill(CLIENT.email);
    await page.getByTestId('send-code').click();

    // The SMS path needs Firebase Auth in the browser; the email code is the one the emulator fixes.
    await expect(page.getByTestId('code')).toBeVisible();
    await page.getByTestId('use-email').click();
    await expect.poll(() => apiCalls(requests, 'sendEmailCode').length).toBeGreaterThan(0);
    await page.getByTestId('code').fill(EMAIL_CODE);
    await page.getByTestId('verify').click();

    await expect(page.getByTestId('confirm')).toBeVisible();
    await page.getByTestId('heard-friend').click();
    await page.getByTestId('before-no').click();
    await page.getByTestId('confirm').click();

    await expect(page.getByTestId('booking-card')).toBeVisible();
    const href = (await page.getByTestId('view-appointment').getAttribute('href')) ?? '';
    const token = /\/m\/([A-Za-z0-9_-]+)/.exec(href)?.[1];
    expect(token, 'the personal link on the confirmation').toBeDefined();
    story.token = token ?? '';

    const create = apiCalls(requests, 'createBooking');
    expect(create).toHaveLength(1);
    const sent = JSON.parse(create[0]?.body ?? '{}') as { data: Record<string, unknown> };
    expect(sent.data).toMatchObject({ slug: SLUG, startsAt: story.startsAt, verification: { method: 'email' }, client: { name: CLIENT.name, email: CLIENT.email } });
    // The token never travels in a URL (docs/06 section 5).
    for (const request of requests) expect(request.url).not.toContain(story.token);

    const [booking] = await store.bookings();
    expect(booking?.data).toMatchObject({ ownerUid: UID, status: 'confirmed', startsAt: story.startsAt, rescheduleCount: 0, client: { name: CLIENT.name, phone: '+5511987654321', email: CLIENT.email } });
    story.bookingId = booking?.id ?? '';

    // A new booking reaches Maria's iPhone as a push, and Helena's address as an email (counted, never written down).
    await waitFor(async () => (await store.outbox()).some((entry) => entry['type'] === 'push' && entry['kind'] === 'booking' && entry['id'] === story.bookingId), 'the booking push');
    expect((await store.outbox()).filter((entry) => entry['type'] === 'email').length).toBeGreaterThanOrEqual(2);
  });

  test('she moves the visit to another time from her link, straight away (inside the free window)', async ({ page, requests, store }) => {
    await open(page, `/m/${story.token}`);
    await expect(page.getByTestId('booking-card')).toBeVisible();
    await expect(page.getByTestId('actions')).toBeVisible();
    await page.getByTestId('reschedule').click();
    await expect(page.getByTestId('current-time')).toBeVisible();

    const slots = page.locator('[data-testid^="slot-"]');
    await expect(slots.first()).toBeVisible();
    const candidates = (await slots.evaluateAll((elements) => elements.map((element) => element.getAttribute('data-testid') ?? ''))).map((id) => id.replace('slot-', ''));
    const target = candidates.find((slot) => slot !== story.startsAt);
    expect(target, 'another free time on the same day').toBeDefined();
    story.movedTo = target ?? '';
    await page.getByTestId(`slot-${story.movedTo}`).click();
    await page.getByTestId('confirm-reschedule').click();
    await expect(page.getByTestId('done-text')).toBeVisible();

    expect(apiCalls(requests, 'rescheduleBooking')).toHaveLength(1);
    expect(apiCalls(requests, 'requestReschedule')).toHaveLength(0);
    const [booking] = await store.bookings();
    expect(booking?.data).toMatchObject({ status: 'confirmed', startsAt: story.movedTo, rescheduleCount: 1 });
  });

  test('she fills in the health form: only a sealed envelope leaves, and Maria gets an item and a silent push', async ({ page, requests, store }) => {
    await open(page, `/m/${story.token}/form`);
    await expect(page.getByTestId('submit-intake')).toBeVisible();
    await page.getByTestId('answer-allergies-latex').click();
    await tap(page, 'answer-medication-yes');
    await tap(page, 'answer-pregnant-no');
    await tap(page, 'answer-skinCondition-no');
    await tap(page, 'answer-isotretinoin-no');
    await page.getByTestId('answer-anythingElse').fill(SECRET);
    await page.getByTestId('typed-signature').fill(CLIENT.name);
    await tap(page, 'consent');
    await page.getByTestId('submit-intake').click();
    await expect(page.getByTestId('sealed-message')).toBeVisible();

    const sent = apiCalls(requests, 'submitSealed');
    expect(sent).toHaveLength(1);
    const envelope = (JSON.parse(sent[0]?.body ?? '{}') as { data: { envelope: Envelope } }).data.envelope;
    expect(Object.keys(envelope).sort()).toEqual(['ct', 'enc', 'itemId', 'keyId', 'kind', 'suite', 'v']);
    expect(envelope).toMatchObject({ v: 1, suite: 'hpke-x25519-hkdf-sha256-chacha20poly1305', kind: 'intake' });
    story.envelope = envelope;
    // Nothing typed into the form is anywhere on the wire in clear (docs/06 section 11, test 7).
    for (const request of requests) {
      for (const secret of [SECRET, 'latex']) {
        expect(request.body ?? '', `${request.method} ${request.url}`).not.toContain(secret);
        expect(request.url).not.toContain(encodeURIComponent(secret));
      }
    }

    // The server stored the opaque envelope and its metadata, nothing else, and told the iPhone.
    const items = await store.inbox(UID);
    expect(items).toHaveLength(1);
    const item = items[0]?.data ?? {};
    expect(item).toMatchObject({ ownerUid: UID, bookingId: story.bookingId, kind: 'intake', keyId: envelope.keyId, envelope: { itemId: envelope.itemId, ct: envelope.ct } });
    expect(JSON.stringify(item)).not.toContain(SECRET);
    await waitFor(async () => (await store.outbox()).some((entry) => entry['type'] === 'push' && entry['kind'] === 'mailbox' && entry['id'] === envelope.itemId), 'the mailbox push');
    const [booking] = await store.bookings();
    expect(booking?.data['intakeSubmittedAt']).toBeDefined();
  });

  test('she cancels for free, and the page says so afterwards', async ({ page, requests, store }) => {
    await open(page, `/m/${story.token}`);
    await page.getByTestId('cancel').click();
    await expect(page.getByTestId('confirm-cancel')).toBeVisible();
    await expect(page.getByTestId('counts-warning')).toHaveCount(0);
    await page.getByTestId('reason-conflict').click({ force: true });
    await page.getByTestId('confirm-cancel').click();
    await expect(page.getByTestId('done-text')).toBeVisible();

    const cancel = apiCalls(requests, 'cancelBooking');
    expect(cancel).toHaveLength(1);
    expect(JSON.parse(cancel[0]?.body ?? '{}')).toMatchObject({ data: { token: story.token } });
    const [booking] = await store.bookings();
    expect(booking?.data).toMatchObject({ status: 'cancelledByClient', cancelledBy: 'client' });

    await open(page, `/m/${story.token}`);
    await expect(page.getByTestId('cancelled')).toBeVisible();
  });

  test('the emulator outbox shows every kind of message the story produced', async ({ store }) => {
    const outbox = await store.outbox();
    const pushKinds = new Set(outbox.filter((entry) => entry['type'] === 'push').map((entry) => entry['kind']));
    expect([...pushKinds].sort()).toEqual(['booking', 'mailbox']);
    // The code, the confirmation and the two changes: the provider counted them and wrote nothing down.
    expect(outbox.filter((entry) => entry['type'] === 'email').length).toBeGreaterThanOrEqual(2);
    for (const entry of outbox) {
      expect(JSON.stringify(entry)).not.toMatch(/helena|example\.com|@/i);
    }
  });
});
