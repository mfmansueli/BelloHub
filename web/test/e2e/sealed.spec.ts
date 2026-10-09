// The promise that matters most (docs/06 section 3, docs/10 section 5): a health answer, a skin photo, a note or a
// data request leaves the browser only as a sealed envelope. These tests type recognizable secrets and then look at
// every byte that went over the wire, every storage area and what the (stand-in) professional's phone could open.

import type { Page } from '@playwright/test';

import { expect, open, tap, test, type Guard, type InboxItem } from './support';

const SECRET = 'SECRET-ANSWER-7f3a91';
const NAME = 'Helena Duarte';
const MINOR = 'Bia Duarte';
const HOUR = 60;
// One red pixel. The page re-encodes whatever it is given as a JPEG, which drops metadata.
const PNG_1PX = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');

interface Envelope {
  v: number;
  suite: string;
  keyId: string;
  kind: string;
  itemId: string;
  enc: string;
  ct: string;
}

async function answerIntake(page: Page, options: { minor?: boolean } = {}): Promise<void> {
  await expect(page.getByTestId('submit-intake')).toBeVisible();
  if (options.minor === true) {
    await tap(page, 'minor-yes');
    await page.getByTestId('minor-name').fill(MINOR);
  } else {
    await tap(page, 'answer-pregnant-no');
  }
  await page.getByTestId('answer-allergies-latex').click();
  await tap(page, 'answer-medication-yes');
  await tap(page, 'answer-skinCondition-no');
  await tap(page, 'answer-isotretinoin-no');
  await page.getByTestId('answer-anythingElse').fill(SECRET);
}

/** The form carries no consent text, agreement, tick box or signature of any kind (D55). */
async function expectNoConsentOrSignature(page: Page): Promise<void> {
  for (const id of ['consent', 'consent-text', 'consent-check', 'consent-unavailable', 'typed-signature', 'guardian-name', 'signature-canvas', 'signature-clear']) {
    await expect(page.getByTestId(id)).toHaveCount(0);
  }
  await expect(page.locator('canvas')).toHaveCount(0);
  await expect(page.locator('input[type="checkbox"][name="consent"]')).toHaveCount(0);
}

function envelopes(guard: Guard): Envelope[] {
  return guard.requests
    .filter((request) => request.method === 'POST' && request.url.endsWith('/api/submitSealed'))
    .map((request) => (JSON.parse(request.body ?? '{}') as { data: { envelope: Envelope } }).data.envelope);
}

/** Nothing typed into a sealed page may appear in clear in any request URL or body. */
function expectNoClearText(guard: Guard, secrets: readonly string[]): void {
  for (const request of guard.requests) {
    for (const secret of secrets) {
      expect(request.url, `${request.method} ${request.url}`).not.toContain(encodeURIComponent(secret));
      expect(request.body ?? '', `${request.method} ${request.url}`).not.toContain(secret);
    }
  }
}

async function expectNotStored(page: Page, secrets: readonly string[]): Promise<void> {
  const stored = await page.evaluate(() => JSON.stringify({ local: Object.fromEntries(Object.entries(localStorage)), session: Object.fromEntries(Object.entries(sessionStorage)), cookie: document.cookie }));
  for (const secret of secrets) expect(stored).not.toContain(secret);
}

function onlyItem(items: InboxItem[]): InboxItem {
  expect(items).toHaveLength(1);
  return items[0] as InboxItem;
}

test.describe('no consent on the web (D55)', () => {
  test('the form shows the questions only: no consent text, no agreement, no tick box, no signature, for an adult or a minor', async ({ page, mock, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: 50 * HOUR });
    await open(page, `/m/${token}/form`);
    await expect(page.getByTestId('submit-intake')).toBeVisible();
    await expectNoConsentOrSignature(page);
    await expect(page.locator('main')).not.toContainText(/I agree|consent/i);
    await tap(page, 'minor-yes');
    await expect(page.getByTestId('minor-name')).toBeVisible();
    await expectNoConsentOrSignature(page);
    await expect(page.locator('main')).not.toContainText(/I agree|consent|guardian text/i);
  });
});

test.describe('the health form (Cl-4)', () => {
  test('an adult answers and sends: only a sealed envelope leaves, and only the professional can open it @core', async ({ page, mock, guard, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
    await open(page, `/m/${token}/form`);
    await answerIntake(page);
    await page.getByTestId('submit-intake').click();
    await expect(page.getByTestId('sealed-message')).toBeVisible();

    // What went over the wire.
    const sent = envelopes(guard);
    expect(sent).toHaveLength(1);
    const envelope = sent[0] as Envelope;
    expect(Object.keys(envelope).sort()).toEqual(['ct', 'enc', 'itemId', 'keyId', 'kind', 'suite', 'v']);
    expect(envelope).toMatchObject({ v: 1, suite: 'hpke-x25519-hkdf-sha256-chacha20poly1305', kind: 'intake' });
    expectNoClearText(guard, [SECRET, 'latex']);

    // What the professional's phone opens: exactly what was typed, and nothing signed (D55).
    const item = onlyItem(await mock.inbox(slug));
    expect(item.kind).toBe('intake');
    expect(item.itemId).toBe(envelope.itemId);
    expect(item.payload).toMatchObject({
      schema: 2,
      isForMinor: false,
      answers: { allergies: ['latex'], medication: true, pregnant: false, skinCondition: false, isotretinoin: false, anythingElse: SECRET },
    });
    expect(Object.keys(item.payload).sort()).toEqual(['_pad', 'answers', 'bookingId', 'formVersion', 'isForMinor', 'localeId', 'schema', 'submittedAt']);
    // Padded to a multiple of 1 KiB, plus the 16-byte authentication tag (docs/06 section 3.1).
    expect((item.sizeBytes - 16) % 1024).toBe(0);

    await expectNotStored(page, [SECRET]);
    expect((await mock.bookings(slug))[0]?.intake).toBe('done');
  });

  test('for a minor the same questions are answered with the young person\'s name, and nobody signs anything', async ({ page, mock, guard, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
    await open(page, `/m/${token}/form`);
    await answerIntake(page, { minor: true });
    await page.getByTestId('submit-intake').click();
    await expect(page.getByTestId('sealed-message')).toBeVisible();
    expectNoClearText(guard, [SECRET, MINOR]);
    const item = onlyItem(await mock.inbox(slug));
    expect(item.payload).toMatchObject({ isForMinor: true, minorName: MINOR });
    expect(item.payload).not.toHaveProperty('guardianName');
    expect(item.payload).not.toHaveProperty('consent');
    await expectNotStored(page, [SECRET, MINOR]);
    // Questions meant for adults are not asked of a minor and never sent.
    expect(item.payload['answers']).not.toHaveProperty('pregnant');
  });

  test('missing answers are listed and nothing is sent until the form is complete', async ({ page, mock, guard, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: 50 * HOUR });
    await open(page, `/m/${token}/form`);
    await page.getByTestId('submit-intake').click();
    await expect(page.getByRole('alert').first()).toBeVisible();
    expect(envelopes(guard)).toHaveLength(0);
  });

  test('a failed send keeps the answers and retries with the same sealed bytes, so the server stores one item', async ({ page, mock, guard, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
    let calls = 0;
    await page.route('**/api/submitSealed', async (route) => {
      calls += 1;
      if (calls === 1) await route.fulfill({ status: 503, contentType: 'application/json', body: JSON.stringify({ error: { status: 'UNAVAILABLE', message: 'TRY_AGAIN' } }) });
      else await route.continue();
    });
    await open(page, `/m/${token}/form`);
    await answerIntake(page);
    await page.getByTestId('submit-intake').click();
    await expect(page.getByTestId('retry-hint')).toBeVisible();
    await expect(page.getByTestId('answer-anythingElse')).toHaveValue(SECRET);
    await page.getByTestId('submit-intake').click();
    await expect(page.getByTestId('sealed-message')).toBeVisible();

    const [first, second] = envelopes(guard);
    expect(first?.itemId).toBe(second?.itemId);
    expect(first?.ct).toBe(second?.ct);
    onlyItem(await mock.inbox(slug));
  });

  test('a key the server swapped without recomputing its id is refused and nothing is sent', async ({ page, mock, guard, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: 50 * HOUR });
    await page.route('**/api/getFormContext', async (route) => {
      const response = await route.fetch();
      const json = (await response.json()) as { result: { inboxKey: { pub: string } } };
      const key = json.result.inboxKey;
      key.pub = (key.pub.startsWith('A') ? 'B' : 'A') + key.pub.slice(1);
      await route.fulfill({ response, json });
    });
    await open(page, `/m/${token}/form`);
    await answerIntake(page);
    await page.getByTestId('submit-intake').click();
    await expect(page.getByTestId('seal-failed')).toBeVisible();
    expect(envelopes(guard)).toHaveLength(0);
  });

  test('a form already sent in the last twelve months says so and offers to send again', async ({ page, mock, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: 50 * HOUR, intake: 'done' });
    await open(page, `/m/${token}/form`);
    await expect(page.getByTestId('already')).toBeVisible();
    await page.getByTestId('redo').click();
    await expect(page.getByTestId('submit-intake')).toBeVisible();
  });
});

test.describe('the skin check-in (Cl-5)', () => {
  test('a feeling, a note and a photo are sealed together; the photo is a re-encoded JPEG and the padding blurs its size @core', async ({ page, mock, guard, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: -24 * HOUR, status: 'completed', checkIn: true });
    await open(page, `/m/${token}/checkin`);
    await tap(page, 'feeling-irritated');
    await page.getByTestId('checkin-note').fill(SECRET);
    await page.getByTestId('photo-input').setInputFiles({ name: 'my-skin-photo.png', mimeType: 'image/png', buffer: PNG_1PX });
    await expect(page.getByTestId('photo-preview')).toBeVisible();
    await page.getByTestId('send-checkin').click();
    await expect(page.getByTestId('checkin-reply')).toBeVisible();

    expect(envelopes(guard)).toHaveLength(1);
    expectNoClearText(guard, [SECRET, 'my-skin-photo']);
    const item = onlyItem(await mock.inbox(slug));
    expect(item.kind).toBe('checkin');
    expect(item.payload).toMatchObject({ feeling: 'irritated', note: SECRET });
    // "/9j/" is the base64 of a JPEG header: the PNG was re-encoded in a canvas.
    expect(String(item.payload['photoJpeg'])).toMatch(/^\/9j\//);
    expect((item.sizeBytes - 16) % (16 * 1024)).toBe(0);
    await expectNotStored(page, [SECRET]);
  });

  test('without a photo it is padded to 1 KiB like the form', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: -24 * HOUR, status: 'completed', checkIn: true });
    await open(page, `/m/${token}/checkin`);
    await tap(page, 'feeling-good');
    await page.getByTestId('send-checkin').click();
    await expect(page.getByTestId('checkin-reply')).toBeVisible();
    const item = onlyItem(await mock.inbox(slug));
    expect(item.payload).toMatchObject({ feeling: 'good' });
    expect((item.sizeBytes - 16) % 1024).toBe(0);
  });

  test('pressing send before choosing a feeling asks for one and sends nothing', async ({ page, mock, guard, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: -24 * HOUR, status: 'completed', checkIn: true });
    await open(page, `/m/${token}/checkin`);
    await page.getByTestId('send-checkin').click();
    await expect(page.getByTestId('feeling-missing')).toBeVisible();
    expect(envelopes(guard)).toHaveLength(0);
  });
});

test.describe('my data (Cl-7)', () => {
  test('a copy request travels sealed: the name and phone are not readable on the wire', async ({ page, mock, guard, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
    await open(page, `/m/${token}/data`);
    await page.getByTestId('ask-copy').click();
    await page.getByTestId('request-name').fill(NAME);
    await page.getByTestId('request-phone').fill('11 98765 4321');
    await page.getByTestId('request-note').fill(SECRET);
    await page.getByTestId('send-request').click();
    await expect(page.getByTestId('ask-copy')).toBeDisabled();

    expectNoClearText(guard, [NAME, SECRET, '987654321']);
    const item = onlyItem(await mock.inbox(slug));
    expect(item.kind).toBe('datarequest');
    expect(item.payload).toMatchObject({ request: 'copy', name: NAME, note: SECRET });
    expect((item.sizeBytes - 16) % 1024).toBe(0);
  });

  test('a deletion request is sent the same way and is confirmed on the page', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
    await open(page, `/m/${token}/data`);
    await page.getByTestId('ask-delete').click();
    await page.getByTestId('request-name').fill(NAME);
    await page.getByTestId('request-phone').fill('11 98765 4321');
    await page.getByTestId('send-request').click();
    await expect(page.getByTestId('ask-delete')).toBeDisabled();
    expect(onlyItem(await mock.inbox(slug)).payload).toMatchObject({ request: 'delete' });
  });
});
