// End-to-end tests against the production build served by the mock API (never a real backend, docs/13).
//
//   npm run e2e                 build the test bundle, start the mock, run every project
//   npm run e2e -- --project=chromium test/e2e/booking.spec.ts
//
// Three projects: Chromium on a phone profile, WebKit (what iPhone Safari and the in-app browsers run on), and a
// throttled "low-end" Chromium (4x slower CPU, slow 4G) that runs the core flows and the performance budget.
// Every test gets its own professional (`maria-t<id>`), so tests run in parallel against one mock without a reset.

import { defineConfig, devices } from '@playwright/test';

import type { Options } from './test/e2e/support';

const port = Number(process.env['E2E_PORT'] ?? 4010);

export default defineConfig<Options>({
  testDir: 'test/e2e',
  outputDir: 'test-results',
  fullyParallel: true,
  forbidOnly: process.env['CI'] !== undefined,
  retries: process.env['CI'] === undefined ? 0 : 1,
  workers: Number(process.env['E2E_WORKERS'] ?? 4),
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: process.env['CI'] === undefined ? [['list']] : [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: `http://127.0.0.1:${port}`,
    locale: 'en-US',
    timezoneId: 'America/Sao_Paulo',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  webServer: {
    command: 'npx tsx test/mock-server/main.ts --serve-dist dist-e2e',
    url: `http://127.0.0.1:${port}/__test/waitlist`,
    reuseExistingServer: process.env['CI'] === undefined,
    timeout: 60_000,
    env: { PORT: String(port) },
  },
  projects: [
    { name: 'chromium', use: { ...devices['Pixel 7'] }, grepInvert: /@perf/ },
    { name: 'webkit', use: { ...devices['iPhone 14'] }, grepInvert: /@perf/ },
    {
      name: 'lowend',
      // An inexpensive Android phone: small screen, a CPU four times slower than a laptop, a 1.6 Mbit/s link.
      use: { ...devices['Moto G4'], lowEnd: true },
      grep: /@core|@perf/,
    },
  ],
});
