// "I didn't get the code" (Confirm on WhatsApp, an unverified request), correcting the address on Bk-6, the hold that
// covers the code, and trusted devices (returning clients skip the code). API.md 5.5, 5.8, 5.18.

import type { Page } from '@playwright/test';

import { bookEverything, chooseService, chooseSlot, confirmFirstVisit, DEFAULTS, EMAIL_CODE, fillYou, verify } from './flows';
import { expect, noHorizontalScroll, open, test } from './support';

const REFERENCE = /^[2-9A-HJKMNP-Z]{5}$/;

/** Up to Bk-6 with a fake clock, so the first wait can be skipped. */
async function toVerify(page: Page, slug: string, email: string = DEFAULTS.email): Promise<void> {
  await page.clock.install();
  await chooseService(page, slug);
  await chooseSlot(page);
  await fillYou(page, { email });
  await expect(page.getByTestId('code')).toBeVisible();
}

async function openHelp(page: Page): Promise<void> {
  await expect(page.getByTestId('no-code')).toHaveCount(0);
  await page.clock.fastForward(31_000);
  await page.getByTestId('no-code').click();
  await expect(page.getByTestId('no-code-sheet')).toBeVisible();
}

test.describe('"I didn\'t get the code" (Bk-6)', () => {
  test('after the first wait it offers the spam folder, a new code, a new address and WhatsApp; WhatsApp makes an unverified request @core', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    await toVerify(page, slug);
    await openHelp(page);
    await expect(page.getByTestId('help-spam')).toContainText(DEFAULTS.email);
    await expect(page.getByTestId('help-resend')).toBeVisible();
    await expect(page.getByTestId('help-change-email')).toBeVisible();

    await page.getByTestId('confirm-whatsapp').click();

    // Bk-10, unverified version: the reference, the prefilled message, when the time is released.
    const reference = (await page.getByTestId('reference').textContent())?.trim() ?? '';
    expect(reference).toMatch(REFERENCE);
    await expect(page.getByTestId('request-expires')).toBeVisible();
    const href = (await page.getByTestId('send-whatsapp').getAttribute('href')) ?? '';
    expect(href).toMatch(/^https:\/\/wa\.me\/5511987654321\?text=/);
    const message = decodeURIComponent(href.split('?text=')[1] ?? '');
    expect(message).toContain(reference);
    expect(message).toContain('Helena');
    expect(message).not.toContain('Duarte');
    expect(message).toContain('Brazilian');

    const [booking] = await mock.bookings(slug);
    expect(booking).toMatchObject({ status: 'pendingApproval', verification: 'whatsapp', reference, client: { email: DEFAULTS.email } });
    // Nothing from the first-visit screen travelled: she never reached it.
    expect(booking?.note).toBeNull();
  });

  test('offers no WhatsApp way when the professional has no public number', async ({ page, slugFor }) => {
    await toVerify(page, slugFor('maria-nowa'));
    await openHelp(page);
    await expect(page.getByTestId('help-spam')).toBeVisible();
    await expect(page.getByTestId('help-whatsapp')).toHaveCount(0);
  });

  test('the address can be corrected on the code step, and the code goes to the new one', async ({ page, mock, slugFor, guard }) => {
    const slug = slugFor('maria');
    await toVerify(page, slug, 'helena@exmaple.com');
    await page.getByTestId('change-email').click();
    await page.getByTestId('new-email').fill('not an address');
    await page.getByTestId('save-email').click();
    await expect(page.getByRole('alert')).toBeVisible();
    await page.getByTestId('new-email').fill('helena@example.com');
    await page.getByTestId('save-email').click();
    await expect(page.getByTestId('via')).toContainText('example.com');

    const lastCode = (): string => guard.requests.filter((request) => request.url.endsWith('/sendEmailCode')).at(-1)?.body ?? '';
    await expect.poll(lastCode).toContain('helena@example.com');
    await verify(page, { code: EMAIL_CODE });
    await confirmFirstVisit(page);
    await expect(page.getByTestId('booking-card')).toBeVisible();
    expect((await mock.bookings(slug))[0]?.client.email).toBe('helena@example.com');
  });

  test('the booking code carries the hold key, so the hold lasts as long as the code', async ({ page, slugFor, guard }) => {
    await toVerify(page, slugFor('maria'));
    const firstCode = (): string => guard.requests.find((request) => request.url.endsWith('/sendEmailCode'))?.body ?? '';
    await expect.poll(firstCode).not.toBe('');
    const body = firstCode();
    const sent = (JSON.parse(body) as { data: { purpose?: string; holdKey?: string } }).data;
    expect(sent.purpose).toBe('booking');
    expect(sent.holdKey).toMatch(/^[A-Za-z0-9_-]{16,64}$/);
  });

  test('right to left: the help sheet and the request read in Arabic and fit the screen', async ({ page, slugFor }) => {
    test.skip(test.info().project.name === 'lowend', 'covered by the other projects');
    await page.setViewportSize({ width: 320, height: 640 });
    await page.context().addInitScript(() => { window.localStorage.setItem('bh.lang', 'ar'); });
    await toVerify(page, slugFor('maria'));
    await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
    await openHelp(page);
    await noHorizontalScroll(page);
    await page.getByTestId('confirm-whatsapp').click();
    await expect(page.getByTestId('reference')).toHaveAttribute('dir', 'ltr');
    await noHorizontalScroll(page);
  });

  test('a long-string language (German) fits the help sheet and the request at 320 px', async ({ page, slugFor }) => {
    test.skip(test.info().project.name === 'lowend', 'covered by the other projects');
    await page.setViewportSize({ width: 320, height: 640 });
    await page.context().addInitScript(() => { window.localStorage.setItem('bh.lang', 'de'); });
    await toVerify(page, slugFor('maria'));
    await openHelp(page);
    await noHorizontalScroll(page);
    await page.getByTestId('confirm-whatsapp').click();
    await expect(page.getByTestId('send-whatsapp')).toBeVisible();
    await noHorizontalScroll(page);
  });
});

test.describe('trusted device (returning clients skip the code)', () => {
  test('a second booking with the same address on the same page skips the code @core', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    await bookEverything(page, slug);
    const stored = await page.evaluate((key) => window.localStorage.getItem(key), `bh.device.${slug}`);
    expect(stored).toContain(DEFAULTS.email);

    await chooseService(page, slug);
    await chooseSlot(page, 1);
    await fillYou(page);
    // Straight to the first-visit questions: no code screen.
    await expect(page.getByTestId('confirm')).toBeVisible();
    await expect(page.getByTestId('code')).toHaveCount(0);
    await confirmFirstVisit(page);
    await expect(page.getByTestId('booking-card')).toBeVisible();
    expect((await mock.bookings(slug)).filter((booking) => booking.status === 'confirmed')).toHaveLength(2);
  });

  test('another address on the same browser still gets a code', async ({ page, slugFor }) => {
    const slug = slugFor('maria');
    await bookEverything(page, slug);
    await chooseService(page, slug);
    await chooseSlot(page, 1);
    await fillYou(page, { email: 'someone.else@example.com' });
    await expect(page.getByTestId('code')).toBeVisible();
  });

  test('when the booking would wait for her, the page goes back to the code and keeps the device', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria-approval');
    const device = await mock.seedDevice(slug, DEFAULTS.email);
    await page.context().addInitScript(
      ([key, value]) => { window.localStorage.setItem(key ?? '', value ?? ''); },
      [`bh.device.${slug}`, JSON.stringify({ v: 1, email: DEFAULTS.email, token: device.token, expiresAt: device.expiresAt })],
    );
    await chooseService(page, slug);
    await chooseSlot(page);
    await fillYou(page);
    await confirmFirstVisit(page);

    await expect(page.getByTestId('code')).toBeVisible();
    await verify(page, { code: EMAIL_CODE });
    await confirmFirstVisit(page);
    await expect(page.getByTestId('review-reason')).toBeVisible();
    expect(await page.evaluate((key) => window.localStorage.getItem(key), `bh.device.${slug}`)).toContain(device.token);
  });

  test('an in-app browser that blocks storage books with the code every time, without errors', async ({ page, slugFor }) => {
    await page.context().addInitScript(() => {
      Object.defineProperty(window, 'localStorage', {
        get() {
          throw new DOMException('The operation is insecure.', 'SecurityError');
        },
      });
    });
    const slug = slugFor('maria');
    await bookEverything(page, slug);
    await chooseService(page, slug);
    await chooseSlot(page, 1);
    await fillYou(page);
    await expect(page.getByTestId('code')).toBeVisible();
  });

  test('"Forget this device" on the appointment page: the next booking asks for a code again', async ({ page, slugFor }) => {
    const slug = slugFor('maria');
    await bookEverything(page, slug);
    await page.getByTestId('view-appointment').click();
    await page.getByTestId('forget-device').click();
    await expect(page.getByTestId('device-forgotten')).toBeVisible();
    expect(await page.evaluate((key) => window.localStorage.getItem(key), `bh.device.${slug}`)).toBeNull();

    await chooseService(page, slug);
    await chooseSlot(page, 1);
    await fillYou(page);
    await expect(page.getByTestId('code')).toBeVisible();
  });

  test('the appointment page offers nothing to forget when this browser keeps no device', async ({ page, mock, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: 3000 });
    await open(page, `/m/${token}`);
    await expect(page.getByTestId('actions')).toBeVisible();
    await expect(page.getByTestId('forget-device')).toHaveCount(0);
  });
});
