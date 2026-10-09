// axe-core on every page of the product, in English and in Arabic, plus dark mode and Increase Contrast.
// WCAG 2.2 AA, zero violations. Chromium only: axe injects into the page and the rules are the same in every engine.

import AxeBuilder from '@axe-core/playwright';
import type { Page } from '@playwright/test';

import { bookUntilResult, chooseService, chooseSlot, confirmFirstVisit, fillYou, verify } from './flows';
import { expect, open, tap, test, type Mock } from './support';

const HOUR = 60;

async function scan(page: Page, label: string): Promise<void> {
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice']).analyze();
  const found = results.violations.map(
    (violation) =>
      `${violation.id} (${violation.impact ?? '?'}): ${violation.help}\n` +
      violation.nodes
        .slice(0, 4)
        .map((node) => `    ${node.target.join(' ')}\n      ${(node.any[0]?.message ?? node.failureSummary ?? '').replace(/\s+/g, ' ')}`)
        .join('\n'),
  );
  expect(found, `axe on ${label}`).toEqual([]);
}

async function seedAll(mock: Mock, slug: string): Promise<{ token: string; lateToken: string; doneToken: string; portalToken: string }> {
  const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
  const { token: lateToken } = await mock.seed({ slug, startsInMinutes: 1 * HOUR, phone: '+5511900000555' });
  const done = await mock.seed({ slug, startsInMinutes: -24 * HOUR, status: 'completed', checkIn: true, phone: '+5511900000666' });
  return { token, lateToken, doneToken: done.token, portalToken: done.portalToken };
}

for (const locale of ['en-US', 'ar'] as const) {
  test.describe(`axe, no violations (${locale})`, () => {
    // Pages fade in on arrival; axe would measure the colours halfway through the fade, which is not what a person reads.
    test.use({ locale, reducedMotion: 'reduce' });
    test.skip(({ browserName }) => browserName !== 'chromium', 'axe runs on Chromium');
    test.skip(({ lowEnd }) => lowEnd, 'not a performance test');

    test('the public pages and their sheets', async ({ page, slugFor }) => {
      test.slow();
      const slug = slugFor('maria');
      await open(page, '/');
      await scan(page, 'landing');
      await open(page, '/privacy');
      await scan(page, 'privacy');
      await open(page, `/${slug}`);
      await scan(page, 'Bk-1 professional page');
      await page.getByTestId('credentials-open').click();
      await expect(page.getByTestId('credentials-sheet')).toBeVisible();
      await scan(page, 'Bk-1 credentials sheet');
      await page.keyboard.press('Escape');
      await page.getByTestId('lang-open').click();
      await expect(page.getByTestId('lang-sheet')).toBeVisible();
      await scan(page, 'language sheet');
      await page.keyboard.press('Escape');
      await open(page, `/${slugFor('maria-paused')}`);
      await scan(page, 'Bk-1 paused page');
      await open(page, `/${slug}/find`);
      await scan(page, 'Bk-11 find');
      await open(page, '/m/AAAAAAAAAAAAAAAAAAAAAA');
      await scan(page, 'expired link');
      await open(page, '/m/short');
      await scan(page, 'not found');
    });

    test('the booking flow from service to confirmation', async ({ page, slugFor }) => {
      test.slow();
      const slug = slugFor('maria');
      await open(page, `/${slug}`);
      await page.getByTestId('service-brazilian').click();
      await expect(page.getByTestId('continue')).toBeVisible();
      await tap(page, 'addon-brow');
      await page.getByTestId('guests-1').click();
      await scan(page, 'Bk-2 service, add-on and guest');
      await page.getByTestId('continue').click();
      await expect(page.locator('[data-testid^="slot-"]').first()).toBeVisible();
      await scan(page, 'Bk-4 time');
      await page.getByTestId('waitlist-open').click();
      await expect(page.getByTestId('waitlist-sheet')).toBeVisible();
      await scan(page, 'Bk-4 waiting list sheet');
      await page.keyboard.press('Escape');
      await page.locator('[data-testid^="slot-"]').first().click();
      await page.getByTestId('continue').click();
      await expect(page.getByTestId('name')).toBeVisible();
      await scan(page, 'Bk-5 you');
      await page.getByTestId('send-code').click();
      await expect(page.getByRole('alert').first()).toBeVisible();
      await scan(page, 'Bk-5 you, with errors');
      await fillYou(page, { guests: 1 });
      await expect(page.getByTestId('code')).toBeVisible();
      await scan(page, 'Bk-6 verify');
      await verify(page);
      await expect(page.getByTestId('confirm')).toBeVisible();
      await scan(page, 'Bk-7 first visit');
      await page.getByTestId('confirm').click();
      await expect(page.getByTestId('booking-card')).toBeVisible();
      await scan(page, 'Bk-8 confirmed');
      await page.getByTestId('add-calendar').click();
      await expect(page.getByTestId('calendar-sheet')).toBeVisible();
      await scan(page, 'Bk-8 calendar sheet');
    });

    test('the approval and block outcomes', async ({ page, slugFor }) => {
      await bookUntilResult(page, slugFor('maria-approval'));
      await expect(page.getByTestId('review-reason')).toBeVisible();
      await scan(page, 'Bk-10 waiting for approval');
      const blocked = slugFor('maria-noshow');
      await chooseService(page, blocked);
      await chooseSlot(page);
      await fillYou(page, { phone: '11 90000 0002' });
      await verify(page);
      await confirmFirstVisit(page);
      await expect(page.getByTestId('blocked-text')).toBeVisible();
      await scan(page, 'Bk-10 online booking paused for this client');
    });

    test('the management pages', async ({ page, mock, slugFor }) => {
      test.slow();
      const { token, lateToken, doneToken } = await seedAll(mock, slugFor('maria'));
      await open(page, `/m/${token}`);
      await expect(page.getByTestId('actions')).toBeVisible();
      await scan(page, 'Bk-9 manage');
      await page.getByTestId('add-calendar').click();
      await expect(page.getByTestId('calendar-sheet')).toBeVisible();
      await scan(page, 'Bk-9 calendar sheet');
      await page.keyboard.press('Escape');
      await open(page, `/m/${lateToken}`);
      await expect(page.getByTestId('late')).toBeVisible();
      await scan(page, 'Bk-9 manage, close to the visit');
      await open(page, `/m/${token}/reschedule`);
      await expect(page.locator('[data-testid^="slot-"]').first()).toBeVisible();
      await scan(page, 'Cl-9 reschedule');
      await page.locator('[data-testid^="slot-"]').first().click();
      await scan(page, 'Cl-9 reschedule, time chosen');
      await open(page, `/m/${token}/cancel`);
      await scan(page, 'Cl-6 cancel');
      await open(page, `/m/${lateToken}/cancel`);
      await expect(page.getByTestId('confirm-cancel')).toBeVisible();
      await scan(page, 'Cl-6 late cancel');
      await open(page, `/m/${doneToken}`);
      await expect(page.getByTestId('checkin-link')).toBeVisible();
      await scan(page, 'Bk-9 manage, completed');
    });

    test('the sealed pages and the portal', async ({ page, mock, slugFor }) => {
      test.slow();
      const { token, doneToken, portalToken } = await seedAll(mock, slugFor('maria'));
      await open(page, `/m/${token}/form`);
      await expect(page.getByTestId('submit-intake')).toBeVisible();
      await scan(page, 'Cl-4 health form');
      await page.getByTestId('submit-intake').click();
      await expect(page.getByRole('alert').first()).toBeVisible();
      await scan(page, 'Cl-4 health form, with errors');
      await tap(page, 'minor-yes');
      await scan(page, 'Cl-4 health form, for a minor');
      await open(page, `/m/${doneToken}/checkin`);
      await tap(page, 'feeling-reaction');
      await expect(page.getByTestId('worried')).toBeVisible();
      await scan(page, 'Cl-5 check-in with the safety note');
      await open(page, `/m/${token}/data`);
      await scan(page, 'Cl-7 my data');
      await page.getByTestId('ask-copy').click();
      await expect(page.getByTestId('request-sheet')).toBeVisible();
      await scan(page, 'Cl-7 request sheet');
      await page.keyboard.press('Escape');
      await open(page, `/p/${portalToken}`);
      await scan(page, 'Cl-2 portal, appointments');
      await page.getByTestId('tab-journey').click();
      await scan(page, 'Cl-2 portal, journey');
      await page.getByTestId('tab-care').click();
      await scan(page, 'Cl-2 portal, care');
      await open(page, `/p/${portalToken}/rebook`);
      await expect(page.locator('[data-testid^="slot-"]').first()).toBeVisible();
      await scan(page, 'Cl-3 rebook');
    });
  });
}

test.describe('axe in dark mode and with Increase Contrast', () => {
  test.use({ reducedMotion: 'reduce' });
  test.skip(({ browserName }) => browserName !== 'chromium', 'axe runs on Chromium');
  test.skip(({ lowEnd }) => lowEnd, 'not a performance test');

  test('dark mode keeps every pair above 4.5:1', async ({ browser, mock, slugFor }) => {
    test.slow();
    const context = await browser.newContext({ colorScheme: 'dark', reducedMotion: 'reduce', locale: 'en-US', viewport: { width: 390, height: 844 } });
    const page = await context.newPage();
    const slug = slugFor('maria');
    const { token, doneToken } = await seedAll(mock, slug);
    await open(page, `/${slug}`);
    await scan(page, 'dark: professional page');
    await open(page, `/m/${token}`);
    await scan(page, 'dark: manage');
    await open(page, `/m/${token}/form`);
    await scan(page, 'dark: health form');
    await open(page, `/m/${doneToken}/checkin`);
    await tap(page, 'feeling-irritated');
    await scan(page, 'dark: check-in');
    await context.close();
  });

  test('Increase Contrast switches to the stronger tokens and still passes', async ({ page, mock, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await seedAll(mock, slug);
    await open(page, `/${slug}`);
    const normal = await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--ink-2').trim());
    await page.emulateMedia({ contrast: 'more' });
    const stronger = await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--ink-2').trim());
    expect(stronger).not.toBe(normal);
    await scan(page, 'increased contrast: professional page');
    await open(page, `/m/${token}`);
    await page.emulateMedia({ contrast: 'more' });
    await scan(page, 'increased contrast: manage');
  });
});
