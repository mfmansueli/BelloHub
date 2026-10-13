// A design-review tool: walks the pages of the mock professional in one language and saves a PNG of each, so a
// human (or an agent) can look at the real rendering next to design/screenshots/. Needs the mock serving the build:
//
//   npm run build && npx tsx test/mock-server/main.ts --serve-dist &
//   npx tsx scripts/screenshots.ts --locale en --out build/screens/en [--dark] [--width 390]

import { mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { chromium } from '@playwright/test';

function arg(name: string, fallback: string): string {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? (process.argv[index + 1] ?? fallback) : fallback;
}

const locale = arg('locale', 'en');
const out = resolve(arg('out', `build/screens/${locale}`));
const width = Number(arg('width', '390'));
const dark = process.argv.includes('--dark');
const base = arg('base', 'http://127.0.0.1:4010');
mkdirSync(out, { recursive: true });

async function api(path: string, body: unknown): Promise<Record<string, string>> {
  const response = await fetch(`${base}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  return (await response.json()) as Record<string, string>;
}

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width, height: 844 },
  deviceScaleFactor: 2,
  locale,
  colorScheme: dark ? 'dark' : 'light',
  reducedMotion: 'reduce',
  timezoneId: 'America/Sao_Paulo',
});
const page = await context.newPage();

async function shot(name: string): Promise<void> {
  await page.waitForTimeout(250);
  await page.screenshot({ path: `${out}/${name}.png`, fullPage: true });
  process.stdout.write(`${name}\n`);
}

async function go(path: string): Promise<void> {
  await page.goto(`${base}${path}`);
  await page.waitForSelector('main');
}

await api('/__test/reset', {});
await go('/maria');
await shot('bk1-page');
await page.getByTestId('credentials-open').click();
await shot('bk1-credentials');
await page.keyboard.press('Escape');
await page.getByTestId('lang-open').click();
await shot('bk1-language');
await page.keyboard.press('Escape');
await page.getByTestId('service-brazilian').click();
await page.getByTestId('addon-brow').click({ force: true });
await page.getByTestId('guests-1').click();
await shot('bk2-service');
await page.getByTestId('continue').click();
await page.waitForSelector('[data-testid^="slot-"]');
await shot('bk4-time');
await page.locator('[data-testid^="slot-"]').first().click();
await page.getByTestId('continue').click();
await page.waitForSelector('[data-testid="name"]');
await page.getByTestId('name').fill('Helena Duarte');
await page.getByTestId('phone').fill('11 98765 4321');
if (await page.getByTestId('confirm-phone').isVisible()) {
  await page.getByTestId('confirm-phone').fill('11 98765 4321');
}
await page.getByTestId('email').fill('helena@example.com');
if (await page.getByTestId('confirm-email').isVisible()) {
  await page.getByTestId('confirm-email').fill('helena@example.com');
}
await page.getByTestId('guest-name-0').fill('Ana');
await shot('bk5-you');
await page.getByTestId('send-code').click();
await page.waitForSelector('[data-testid="code"]');
await page.getByTestId('code').fill('123456');
await shot('bk6-verify');
await page.getByTestId('verify').click();
await page.waitForSelector('[data-testid="confirm"]');
await shot('bk7-first-visit');
await page.getByTestId('confirm').click();
await page.waitForSelector('[data-testid="booking-card"]');
await shot('bk8-confirmed');
await page.getByTestId('view-appointment').click();
await page.waitForSelector('[data-testid="actions"]');
await shot('bk9-manage');

const seeded = await api('/__test/seed', { slug: 'maria', startsInMinutes: 60 * 30 });
const token = seeded['token'] ?? '';
await go(`/m/${token}/reschedule`);
await page.waitForSelector('[data-testid^="slot-"]');
await shot('cl9-reschedule');
await go(`/m/${token}/cancel`);
await shot('cl6-cancel');
await go(`/m/${token}/form`);
await shot('cl4-intake');
await go(`/m/${token}/data`);
await shot('cl7-my-data');
const done = await api('/__test/seed', { slug: 'maria', startsInMinutes: -60 * 24, status: 'completed', checkIn: true });
await go(`/m/${done['token'] ?? ''}/checkin`);
await shot('cl5-checkin');
await go(`/p/${done['portalToken'] ?? ''}`);
await shot('cl2-portal');
await go(`/p/${done['portalToken'] ?? ''}/rebook`);
await page.waitForSelector('[data-testid^="slot-"]');
await shot('cl3-rebook');
await go('/maria/find');
await shot('bk11-find');
await go('/maria-paused');
await shot('bk1-paused');
await go('/privacy');
await shot('privacy');
await go('/m/AAAAAAAAAAAAAAAAAAAAAA');
await shot('state-not-found');
await browser.close();

