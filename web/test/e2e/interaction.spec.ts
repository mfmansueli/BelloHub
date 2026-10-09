// Keyboard, focus, touch targets, reduced motion and text zoom (WCAG 2.2 AA, docs/10 section 7).

import type { Page } from '@playwright/test';

import { chooseService, chooseSlot, fillYou } from './flows';
import { expect, noHorizontalScroll, open, test } from './support';

const HOUR = 60;

/** Every control a finger or a keyboard can reach, smaller than 44 x 44 CSS px (inline links in a sentence are exempt). */
async function smallTargets(page: Page): Promise<string[]> {
  return page.evaluate(() => {
    const MIN = 44;
    const found: string[] = [];
    const selector = 'button, a[href], select, textarea, summary, [role="tab"], input:not([type="hidden"])';
    for (const element of Array.from(document.querySelectorAll<HTMLElement>(selector))) {
      const style = getComputedStyle(element);
      if (style.display === 'none' || style.visibility === 'hidden') continue;
      if (element.closest('[aria-hidden="true"]') !== null && element.tagName !== 'BUTTON') continue;
      // A hidden checkbox or radio is operated through its label, which is the real target.
      const input = element as HTMLInputElement;
      const isChoice = element.tagName === 'INPUT' && (input.type === 'checkbox' || input.type === 'radio');
      const target: HTMLElement = isChoice ? (element.closest('label') ?? element) : element;
      const rect = target.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) continue;
      // Skip links, sr-only and the skip link while it is off screen.
      if (rect.right < 0 || rect.bottom < 0 && element.classList.contains('skip')) continue;
      // A link or link-styled button inside a sentence is exempt (WCAG 2.5.8 "inline"); one that is the whole paragraph is not.
      const paragraph = element.closest('p');
      const inSentence = paragraph !== null && (paragraph.textContent ?? '').trim().length > (element.textContent ?? '').trim().length + 12;
      if ((element.tagName === 'A' || element.classList.contains('link-button')) && inSentence) continue;
      if (rect.width < MIN - 0.5 || rect.height < MIN - 0.5) {
        const name = element.getAttribute('data-testid') ?? element.className ?? element.tagName;
        found.push(`${element.tagName.toLowerCase()}[${name}] ${Math.round(rect.width)}x${Math.round(rect.height)}`);
      }
    }
    return found;
  });
}

test.describe('touch targets are at least 44 x 44 CSS px', () => {
  test.skip(({ lowEnd }) => lowEnd, 'the layout is the same on the other projects');

  test('on the professional page, the booking steps and the management pages', async ({ page, mock, slugFor }) => {
    test.slow();
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
    const report: Record<string, string[]> = {};
    const check = async (label: string): Promise<void> => {
      report[label] = await smallTargets(page);
    };

    await open(page, `/${slug}`);
    await check('home');
    await chooseService(page, slug);
    await check('service');
    await expect(page.locator('[data-testid^="slot-"]').first()).toBeVisible();
    await check('time');
    await chooseSlot(page);
    await expect(page.getByTestId('name')).toBeVisible();
    await check('you');
    await fillYou(page);
    await expect(page.getByTestId('code')).toBeVisible();
    await check('verify');
    await open(page, `/m/${token}`);
    await check('manage');
    await open(page, `/m/${token}/cancel`);
    await check('cancel');
    await open(page, `/m/${token}/form`);
    await check('form');
    await open(page, `/m/${token}/data`);
    await check('data');
    await open(page, `/p/${await mock.seedPortal(slug)}`);
    await check('portal');

    const failing = Object.fromEntries(Object.entries(report).filter(([, list]) => list.length > 0));
    expect(failing, 'controls smaller than 44 x 44').toEqual({});
  });
});

test.describe('keyboard', () => {
  test('the first Tab reaches "Skip to content" and Enter moves focus to the main area', async ({ page, slugFor }) => {
    test.skip(test.info().project.name === 'webkit', 'Safari does not Tab to links and buttons unless the system option is on');
    await open(page, `/${slugFor('maria')}`);
    await page.keyboard.press('Tab');
    const skip = page.locator('a.skip, a[href="#main"]').first();
    await expect(skip).toBeFocused();
    await page.keyboard.press('Enter');
    await expect.poll(() => page.evaluate(() => document.activeElement?.id)).toBe('main');
  });

  test('every control reached by Tab shows a visible focus indicator', async ({ page, slugFor }) => {
    test.skip(test.info().project.name === 'webkit', 'Safari does not Tab to links and buttons unless the system option is on');
    await open(page, `/${slugFor('maria')}`);
    const hidden: string[] = [];
    for (let step = 0; step < 30; step += 1) {
      await page.keyboard.press('Tab');
      const state = await page.evaluate(() => {
        const element = document.activeElement;
        if (element === null || element === document.body) return null;
        const style = getComputedStyle(element);
        const visible = style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) >= 2 || style.boxShadow !== 'none';
        return { name: element.getAttribute('data-testid') ?? element.tagName, visible };
      });
      if (state !== null && !state.visible) hidden.push(state.name);
    }
    expect(hidden, 'focused controls without an outline or ring').toEqual([]);
  });

  test('moving to the next step puts focus on its heading so a screen reader announces it', async ({ page, slugFor }) => {
    await open(page, `/${slugFor('maria')}`);
    await page.getByTestId('service-brazilian').click();
    await expect(page.getByTestId('continue')).toBeVisible();
    await expect.poll(() => page.evaluate(() => document.activeElement?.id)).toBe('page-title');
    await expect(page.locator('h1#page-title')).toBeFocused();
  });

  test('a sheet traps focus, closes with Escape and gives focus back', async ({ page, slugFor }) => {
    await open(page, `/${slugFor('maria')}`);
    const opener = page.getByTestId('credentials-open');
    await opener.focus();
    await page.keyboard.press('Enter');
    const sheet = page.getByTestId('credentials-sheet');
    await expect(sheet).toBeVisible();
    for (let step = 0; step < 8; step += 1) {
      await page.keyboard.press('Tab');
      // A native modal dialog makes the page behind it inert: focus stays inside, or leaves to the browser (body).
      const where = await sheet.evaluate((dialog) => (dialog.contains(document.activeElement) ? 'dialog' : document.activeElement === document.body ? 'browser' : 'page behind'));
      expect(where).not.toBe('page behind');
    }
    await page.keyboard.press('Escape');
    await expect(sheet).toBeHidden();
    await expect(opener).toBeFocused();
  });

  test('the calendar moves by day and week with the arrow keys, mirrored in Arabic', async ({ page, slugFor, browser }) => {
    const slug = slugFor('maria');
    await chooseService(page, slug);
    await expect(page.locator('[data-testid^="slot-"]').first()).toBeVisible();
    const days = page.locator('button.cal-day:not([aria-disabled="true"])');
    await days.first().focus();
    const start = await page.evaluate(() => document.activeElement?.getAttribute('data-testid') ?? '');
    await page.keyboard.press('ArrowDown');
    const week = await page.evaluate(() => document.activeElement?.getAttribute('data-testid') ?? '');
    expect(week).not.toBe(start);
    expect(Date.parse(week.replace('day-', '')) - Date.parse(start.replace('day-', ''))).toBe(7 * 24 * 3_600_000);

    const arabic = await browser.newContext({ locale: 'ar', viewport: page.viewportSize() ?? { width: 390, height: 844 } });
    const rtlPage = await arabic.newPage();
    await chooseService(rtlPage, slug);
    await expect(rtlPage.locator('[data-testid^="slot-"]').first()).toBeVisible();
    await rtlPage.locator('button.cal-day:not([aria-disabled="true"])').first().focus();
    const first = await rtlPage.evaluate(() => document.activeElement?.getAttribute('data-testid') ?? '');
    await rtlPage.keyboard.press('ArrowLeft');
    const next = await rtlPage.evaluate(() => document.activeElement?.getAttribute('data-testid') ?? '');
    // In a right-to-left page the left arrow goes to the NEXT day.
    expect(Date.parse(next.replace('day-', '')) - Date.parse(first.replace('day-', ''))).toBe(24 * 3_600_000);
    await arabic.close();
  });

  test('a whole booking can be made with the keyboard alone', async ({ page, slugFor }) => {
    test.skip(test.info().project.name === 'webkit', 'Safari does not Tab to links and buttons unless the system option is on');
    await open(page, `/${slugFor('maria')}`);
    await page.getByTestId('service-glow').focus();
    await page.keyboard.press('Enter');
    // The new step takes focus on its heading; only then does the keyboard move on.
    await expect(page.locator('h1#page-title')).toBeFocused();
    await page.getByTestId('continue').focus();
    await page.keyboard.press('Enter');
    const slot = page.locator('[data-testid^="slot-"]').first();
    await expect(slot).toBeVisible();
    await slot.focus();
    await page.keyboard.press('Enter');
    await expect(slot).toHaveAttribute('aria-pressed', 'true');
    await page.getByTestId('continue').focus();
    await page.keyboard.press('Enter');
    await expect(page.locator('h1#page-title')).toBeFocused();
    await page.getByTestId('name').focus();
    await page.keyboard.type('Helena Duarte');
    await page.getByTestId('phone').focus();
    await page.keyboard.type('11 98765 4321');
    await page.getByTestId('send-code').focus();
    await page.keyboard.press('Enter');
    await expect(page.getByTestId('code')).toBeVisible();
    await expect(page.locator('h1#page-title')).toBeFocused();
    await page.getByTestId('code').focus();
    await page.keyboard.type('123456');
    await page.getByTestId('verify').focus();
    await page.keyboard.press('Enter');
    await expect(page.getByTestId('confirm')).toBeVisible();
  });
});

test.describe('motion', () => {
  test('with "reduce motion" nothing animates on arrival or while loading', async ({ browser, slugFor }) => {
    const context = await browser.newContext({ reducedMotion: 'reduce', locale: 'en-US' });
    const page = await context.newPage();
    // Hold the profile back so the loading skeleton is on screen long enough to inspect.
    await page.route('**/api/getPublicPage*', async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 600));
      await route.continue();
    });
    await page.goto(`/${slugFor('maria')}`);
    const loading = await page.evaluate(() => document.getAnimations().filter((animation) => animation.playState === 'running').length);
    expect(loading).toBe(0);
    await expect(page.getByTestId('book')).toBeVisible();
    const after = await page.evaluate(() => document.getAnimations().filter((animation) => animation.playState === 'running').length);
    expect(after).toBe(0);
    await context.close();
  });

  test('without the preference the page does move (so the test above can fail)', async ({ browser, slugFor }) => {
    const context = await browser.newContext({ reducedMotion: 'no-preference', locale: 'en-US' });
    const page = await context.newPage();
    await page.route('**/api/getPublicPage*', async (route) => {
      await new Promise((resolve) => setTimeout(resolve, 600));
      await route.continue();
    });
    await page.goto(`/${slugFor('maria')}`);
    const loading = await page.evaluate(() => document.getAnimations().filter((animation) => animation.playState === 'running').length);
    expect(loading).toBeGreaterThan(0);
    await context.close();
  });
});

test.describe('zoom and text spacing', () => {
  test.skip(({ lowEnd }) => lowEnd, 'the layout is the same on the other projects');

  test('text at 200 percent and the WCAG text-spacing overrides do not overflow or clip the pages', async ({ page, mock, slugFor }) => {
    test.slow();
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * HOUR });
    await page.setViewportSize({ width: 390, height: 844 });
    for (const path of [`/${slug}`, `/m/${token}`, `/m/${token}/cancel`, `/m/${token}/form`, `/${slug}/find`]) {
      await open(page, path);
      // The CSP forbids inline <style>, so the overrides go in a constructed stylesheet (the CSSOM is not under style-src).
      await page.evaluate(() => {
        const sheet = new CSSStyleSheet();
        sheet.replaceSync('html { font-size: 200% !important } * { line-height: 1.5 !important; letter-spacing: 0.12em !important; word-spacing: 0.16em !important } p { margin-block-end: 2em !important }');
        document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet];
      });
      await noHorizontalScroll(page);
      const clipped = await page.evaluate(() =>
        Array.from(document.querySelectorAll<HTMLElement>('button, a.btn, .btn, label:not(.sr-only), h1, h2, h3'))
          .filter((element) => element.offsetParent !== null && element.scrollWidth > element.clientWidth + 2 && getComputedStyle(element).overflowX !== 'visible')
          .map((element) => `${element.tagName.toLowerCase()}[${element.getAttribute('data-testid') ?? element.className}]`),
      );
      expect(clipped, `${path} clipped controls`).toEqual([]);
    }
  });

  test('the inputs are 16 px or more so iOS Safari does not zoom the page on focus', async ({ page, slugFor }) => {
    await chooseService(page, slugFor('maria'));
    await chooseSlot(page);
    await expect(page.getByTestId('name')).toBeVisible();
    const sizes = await page.evaluate(() => Array.from(document.querySelectorAll('input:not([type="hidden"]), textarea, select')).map((element) => parseFloat(getComputedStyle(element).fontSize)));
    expect(sizes.length).toBeGreaterThan(0);
    for (const size of sizes) expect(size).toBeGreaterThanOrEqual(16);
  });
});
