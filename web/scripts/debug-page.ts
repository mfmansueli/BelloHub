// Opens one path of the mock in Chromium and prints what the console, the network and the page say. For debugging.
//   npx tsx scripts/debug-page.ts /maria [--locale en] [--base http://127.0.0.1:4010]

import { chromium } from '@playwright/test';

const path = process.argv[2] ?? '/maria';
const index = process.argv.indexOf('--locale');
const locale = index >= 0 ? (process.argv[index + 1] ?? 'en') : 'en';
const baseIndex = process.argv.indexOf('--base');
const base = baseIndex >= 0 ? (process.argv[baseIndex + 1] ?? 'http://127.0.0.1:4010') : 'http://127.0.0.1:4010';

const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 390, height: 844 }, locale });
const page = await context.newPage();
page.on('console', (message) => process.stdout.write(`console.${message.type()}: ${message.text()}\n`));
page.on('pageerror', (error) => process.stdout.write(`pageerror: ${error.message}\n`));
page.on('requestfailed', (request) => process.stdout.write(`requestfailed: ${request.url()} ${request.failure()?.errorText ?? ''}\n`));
page.on('response', (response) => {
  if (response.status() >= 400) process.stdout.write(`http ${response.status()}: ${response.url()}\n`);
});
await page.goto(`${base}${path}`);
await page.waitForTimeout(1500);
process.stdout.write(`${(await page.locator('body').innerText()).slice(0, 600)}\n`);
await browser.close();
