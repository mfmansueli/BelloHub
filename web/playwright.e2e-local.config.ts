// The end-to-end run against the REAL backend (scripts/e2e-local.sh): the Hosting emulator serves the e2e-local build
// with the /api rewrites of firebase/firebase.json, the Functions emulator runs the compiled functions, and the
// Firestore, Auth and Storage emulators hold the data. Nothing is mocked. The script starts the emulators, seeds Maria
// and sets the variables below; this config starts no server of its own.
//
//   scripts/e2e-local.sh                                   from the repository root (the normal way)
//   npx playwright test -c playwright.e2e-local.config.ts  from web/, with the emulators already running and seeded
//
// One professional, one client, one story, so the tests run in order on one worker (test/e2e-local/booking.spec.ts).

import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env['E2E_LOCAL_BASE'] ?? 'http://127.0.0.1:25080';

export default defineConfig({
  testDir: 'test/e2e-local',
  outputDir: 'test-results/e2e-local',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: process.env['CI'] !== undefined,
  // The Functions emulator starts one worker per function on its first call (a few seconds each).
  timeout: 120_000,
  expect: { timeout: 20_000 },
  reporter: [['list']],
  use: {
    ...devices['Pixel 7'],
    baseURL,
    locale: 'en-US',
    timezoneId: 'America/Sao_Paulo',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium' }],
});
