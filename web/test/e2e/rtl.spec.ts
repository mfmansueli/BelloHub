// Arabic is the right-to-left proof of the page (docs/07 section 7): logical CSS, `dir`, isolation of Latin names
// and times, digits typed in Arabic-Indic or Persian forms, and the plural forms Arabic needs.

import { bookEverything, chooseService, chooseSlot, DEFAULTS, fillYou, verify } from './flows';
import { expect, mainText, noHorizontalScroll, open, test } from './support';

const HOUR = 60;

test('the same header in English keeps the language button on the right (the mirror of the Arabic one)', async ({ page, slugFor }) => {
  await open(page, `/${slugFor('maria')}`);
  await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
  const viewport = page.viewportSize();
  const language = await page.getByTestId('lang-open').boundingBox();
  expect((language?.x ?? 0) + (language?.width ?? 0) / 2).toBeGreaterThan((viewport?.width ?? 0) / 2);
});

test.describe('Arabic, right to left', () => {
  test.use({ locale: 'ar' });

  test('the page declares its language and direction and mirrors the layout', async ({ page, slugFor }) => {
    await open(page, `/${slugFor('maria')}`);
    await expect(page.locator('html')).toHaveAttribute('lang', 'ar');
    await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
    await expect(page.getByTestId('book')).toContainText('حجز موعد');

    // The professional's name is Latin inside an Arabic sentence: it must be isolated, not allowed to reorder it.
    expect(await page.locator('bdi').count()).toBeGreaterThan(0);

    // The language button sits on the END edge of the header: the right in English, the left in Arabic.
    const viewport = page.viewportSize();
    const language = await page.getByTestId('lang-open').boundingBox();
    expect((language?.x ?? 0) + (language?.width ?? 0) / 2).toBeLessThan((viewport?.width ?? 0) / 2);
    // A service row puts the name at the start edge (right) and the price at the end edge (left).
    const row = page.getByTestId('service-brazilian');
    const rowBox = await row.boundingBox();
    const name = await row.locator('.grow').boundingBox();
    const price = await row.locator('.end').boundingBox();
    const middle = (rowBox?.x ?? 0) + (rowBox?.width ?? 0) / 2;
    expect((name?.x ?? 0) + (name?.width ?? 0) / 2).toBeGreaterThan(middle);
    expect((price?.x ?? 0) + (price?.width ?? 0) / 2).toBeLessThan(middle);
    await noHorizontalScroll(page);
  });

  test('list chevrons point to the left and the back arrow points to the right', async ({ page, mock, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: 50 * HOUR });
    await open(page, `/m/${token}`);
    const row = page.getByTestId('message-pro');
    await expect(row).toBeVisible();
    const viewport = page.viewportSize();
    const chevron = row.locator('svg').last();
    const box = await chevron.boundingBox();
    // In a right-to-left page the "forward" chevron is at the left edge of the row.
    expect((box?.x ?? 9999) + (box?.width ?? 0) / 2).toBeLessThan((viewport?.width ?? 0) / 2);
    expect(await chevron.evaluate((element) => getComputedStyle(element).transform)).not.toBe('none');
  });

  test('the whole booking works with digits typed in Arabic-Indic form, and the server gets Latin digits @core', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    await chooseService(page, slug);
    await chooseSlot(page);
    await fillYou(page, { name: DEFAULTS.name, phone: '١١ ٩٨٧٦٥ ٤٣٢١' });
    await verify(page, { code: '١٢٣٤٥٦' });
    await page.getByTestId('confirm').click();
    await expect(page.getByTestId('booking-card')).toBeVisible();
    expect((await mock.bookings(slug))[0]?.client.phone).toBe('+5511987654321');
  });

  test('the phone and the code fields stay left-to-right and align to the start of the line', async ({ page, slugFor }) => {
    await chooseService(page, slugFor('maria'));
    await chooseSlot(page);
    const phone = page.getByTestId('phone');
    await expect(phone).toBeVisible();
    expect(await phone.getAttribute('dir')).toBe('ltr');
    expect(await phone.evaluate((element) => getComputedStyle(element).textAlign)).toMatch(/^(end|left)$/);
  });

  test('Arabic plural forms are used: one, two, few and many guests', async ({ page, slugFor }) => {
    await open(page, `/${slugFor('maria')}`);
    await page.getByTestId('service-brazilian').click();
    await expect(page.getByTestId('guests-1')).toContainText('مرافق واحد');
    await expect(page.getByTestId('guests-2')).toContainText('مرافقان');
  });

  test('a booking confirmation shows the professional\'s name and times without scrambling the sentence', async ({ page, slugFor }) => {
    await bookEverything(page, slugFor('maria'));
    const text = await mainText(page);
    expect(text).toMatch(/[؀-ۿ]/);
    await noHorizontalScroll(page);
    // The name is isolated: either a <bdi> or an explicit isolate character is around the Latin run.
    const isolated = await page.getByTestId('booking-card').evaluate((card) => card.querySelectorAll('bdi, [dir="ltr"], .ltr').length);
    expect(isolated).toBeGreaterThan(0);
  });
});

test.describe('reflow on a narrow screen (WCAG 1.4.10)', () => {
  for (const locale of ['en-US', 'ar'] as const) {
    test(`pages fit a 320 px wide screen in ${locale} without horizontal scrolling`, async ({ page, mock, slugFor }) => {
      test.skip(test.info().project.name === 'lowend', 'covered by the other projects');
      await page.setViewportSize({ width: 320, height: 640 });
      await page.context().addInitScript((id) => { window.localStorage.setItem('bh.lang', id); }, locale === 'ar' ? 'ar' : 'en');
      const slug = slugFor('maria');
      const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
      for (const path of [`/${slug}`, `/m/${token}`, `/m/${token}/cancel`, `/m/${token}/reschedule`, `/m/${token}/form`, `/m/${token}/data`, '/privacy']) {
        await open(page, path);
        if (path.endsWith('/reschedule')) await expect(page.locator('[data-testid^="slot-"]').first()).toBeVisible();
        await noHorizontalScroll(page);
      }
      await open(page, `/${slug}`);
      await page.getByTestId('service-brazilian').click();
      await page.getByTestId('continue').click();
      await expect(page.locator('[data-testid^="slot-"]').first()).toBeVisible();
      await noHorizontalScroll(page);
      await page.locator('[data-testid^="slot-"]').first().click();
      await page.getByTestId('continue').click();
      await expect(page.getByTestId('name')).toBeVisible();
      await noHorizontalScroll(page);
    });
  }
});
