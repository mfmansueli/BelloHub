// The language of the page (docs/07 section 7): a per-page chooser that stores only the language, fourteen
// localizations that all render, and the professional's published texts shown as published.

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { LOCALE_IDS } from '../../src/lib/locales';
import { rulesFor, DEFAULT_POLICY } from '../mock-server/fixtures';
import { expect, mainText, open, test } from './support';

type Catalog = Record<string, string | Record<string, string>>;

function catalog(locale: string): Catalog {
  return JSON.parse(readFileSync(resolve(import.meta.dirname, `../../src/i18n/${locale}.json`), 'utf8')) as Catalog;
}

/** A key that leaked into the page instead of its text ("bk1.book", "cl4.err.sign") or a placeholder left unfilled. */
const LEAK = /\b(?:bk|cl|common|err|state|wait|cal|price|legal|landing|lang|wa|ics)\d*\.[A-Za-z][A-Za-z0-9.]*\b|\{\w+\}/;

test.describe('the language chooser', () => {
  test('switches the whole page at once, stores only the language, and remembers it @core', async ({ page, slugFor }) => {
    await open(page, `/${slugFor('maria')}`);
    await expect(page.getByTestId('book')).toHaveText(String(catalog('en')['bk1.book']));
    await page.getByTestId('lang-open').click();
    await expect(page.getByTestId('lang-sheet')).toBeVisible();
    await page.getByTestId('lang-de').click();
    await expect(page.locator('html')).toHaveAttribute('lang', 'de');
    await expect(page.getByTestId('book')).toHaveText(String(catalog('de')['bk1.book']));

    const stored = await page.evaluate(() => ({ local: Object.fromEntries(Object.entries(localStorage)), session: Object.keys(sessionStorage) }));
    expect(stored.local).toEqual({ 'bh.lang': 'de' });

    await page.reload();
    await expect(page.locator('html')).toHaveAttribute('lang', 'de');
    await expect(page.getByTestId('book')).toHaveText(String(catalog('de')['bk1.book']));
  });

  test('moving from Arabic back to English restores the direction', async ({ page, slugFor }) => {
    await open(page, `/${slugFor('maria')}`);
    await page.getByTestId('lang-open').click();
    await page.getByTestId('lang-ar').click();
    await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
    await page.getByTestId('lang-open').click();
    await page.getByTestId('lang-en').click();
    await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
    await expect(page.locator('html')).toHaveAttribute('lang', 'en');
  });

  test('the sheet closes with Escape and gives focus back to the button that opened it', async ({ page, slugFor }) => {
    await open(page, `/${slugFor('maria')}`);
    await page.getByTestId('lang-open').focus();
    await page.keyboard.press('Enter');
    await expect(page.getByTestId('lang-sheet')).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(page.getByTestId('lang-sheet')).toBeHidden();
    await expect(page.getByTestId('lang-open')).toBeFocused();
  });

  test('the browser language picks the page language when nothing was chosen', async ({ browser, slugFor }) => {
    const context = await browser.newContext({ locale: 'pt-PT' });
    const page = await context.newPage();
    await open(page, `/${slugFor('maria')}`);
    await expect(page.locator('html')).toHaveAttribute('lang', 'pt-PT');
    await expect(page.getByTestId('book')).toHaveText(String(catalog('pt-PT')['bk1.book']));
    await context.close();
  });
});

test.describe('all fourteen localizations', () => {
  test('each one renders the booking page and the manage page with no leaked key or placeholder', async ({ page, mock, slugFor }) => {
    test.setTimeout(180_000);
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * 60 });
    expect(LOCALE_IDS).toHaveLength(14);
    for (const id of LOCALE_IDS) {
      await page.context().addInitScript((value) => { window.localStorage.setItem('bh.lang', value); }, id);
      await open(page, `/${slug}`);
      await expect(page.locator('html'), id).toHaveAttribute('lang', id);
      await expect(page.locator('html'), id).toHaveAttribute('dir', id === 'ar' ? 'rtl' : 'ltr');
      await expect(page.getByTestId('book'), id).toHaveText(String(catalog(id)['bk1.book']));
      expect(await mainText(page), `${id} booking page`).not.toMatch(LEAK);

      await open(page, `/m/${token}`);
      await expect(page.getByTestId('actions'), id).toBeVisible();
      expect(await mainText(page), `${id} manage page`).not.toMatch(LEAK);
    }
  });
});

/** The published text, line by line, as the page shows it. */
function lines(text: string | undefined): string[] {
  return (text ?? '').split('\n').filter((line) => line !== '');
}

test.describe('what the professional published', () => {
  test('her rules are shown exactly as published, in the page language when she wrote it', async ({ page, slugFor }) => {
    const published = rulesFor(DEFAULT_POLICY);
    await page.context().addInitScript(() => { window.localStorage.setItem('bh.lang', 'pt-BR'); });
    await open(page, `/${slugFor('maria')}`);
    const rules = page.getByTestId('rules');
    await expect(rules).toBeVisible();
    const shown = (await rules.locator('li').allInnerTexts()).map((line) => line.trim());
    expect(shown).toEqual(lines(published['pt-BR']));
  });

  test('when she did not publish the page language, the text falls back to hers and says which language it is in', async ({ page, slugFor }) => {
    const published = rulesFor(DEFAULT_POLICY);
    await page.context().addInitScript(() => { window.localStorage.setItem('bh.lang', 'de'); });
    await open(page, `/${slugFor('maria')}`);
    const rules = page.getByTestId('rules');
    await expect(rules).toBeVisible();
    // German was not published; her default language (pt-BR) is. Never a machine translation of her rules.
    const shown = (await rules.locator('li').allInnerTexts()).map((line) => line.trim());
    expect(shown).toEqual(lines(published['pt-BR']));
    await expect(rules).toHaveAttribute('lang', 'pt-BR');
  });

  test('her rules are shown in Arabic, right to left, when she published Arabic', async ({ page, slugFor }) => {
    const published = rulesFor(DEFAULT_POLICY);
    await page.context().addInitScript(() => { window.localStorage.setItem('bh.lang', 'ar'); });
    await open(page, `/${slugFor('maria')}`);
    const shown = (await page.getByTestId('rules').locator('li').allInnerTexts()).map((line) => line.trim());
    expect(shown).toEqual(lines(published['ar']));
  });
});
