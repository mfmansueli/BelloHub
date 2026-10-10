// `npm run lighthouse`: Lighthouse CI on the public page and on a personal link (docs/10 section 9), with the
// thresholds of lighthouserc.json (performance >= 0.9 on mobile, accessibility >= 0.95).
//
// It serves the e2e build through the mock (the production headers, gzip like Hosting), seeds one booking so a
// `/m/<token>` page exists, finds a Chrome and runs `lhci autorun`. Lighthouse needs a Chrome binary: CHROME_PATH
// when set, else the Chromium that Playwright installed. When none is found it prints the command for the owner and
// exits 0 (the budgets of the Playwright low-end project still guard LCP, CLS and the bytes), so a machine without
// Chrome does not fail the suite; LIGHTHOUSE_REQUIRED=1 makes a missing Chrome an error instead.
//
// `@lhci/cli` is NOT a dependency of this package: its tree (puppeteer-core, extract-zip, tmp) carries high audit
// findings with no fixed release, and the lockfile of the page that seals health data stays audit-clean (docs/06
// section 6). The pinned version below is fetched by npx into the npm cache on first use (network needed once).

import { spawn } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { createServer } from 'node:net';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium } from '@playwright/test';

import { startMock } from '../test/mock-server/server';

const here = dirname(fileURLToPath(import.meta.url));
const web = resolve(here, '..');
const dist = resolve(web, 'dist-e2e');
const HOUR = 60;
const LHCI_VERSION = '0.15.1';

function freePort(): Promise<number> {
  return new Promise((done, fail) => {
    const probe = createServer();
    probe.listen(0, '127.0.0.1', () => {
      const address = probe.address();
      const port = typeof address === 'object' && address !== null ? address.port : 0;
      probe.close(() => {
        done(port);
      });
    });
    probe.on('error', fail);
  });
}

function findChrome(): string | null {
  const given = process.env['CHROME_PATH'];
  if (given !== undefined && given !== '' && existsSync(given)) return given;
  try {
    const path = chromium.executablePath();
    if (existsSync(path)) return path;
  } catch {
    // Playwright has no Chromium installed.
  }
  const macOS = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  return existsSync(macOS) ? macOS : null;
}

if (!existsSync(resolve(dist, 'index.html'))) {
  process.stderr.write('error: dist-e2e/ is missing. Run: npm run build:e2e\n');
  process.exit(1);
}

const chrome = findChrome();
const port = await freePort();
const base = `http://127.0.0.1:${String(port)}`;
const mock = await startMock(port, dist);
const { token } = mock.api.seedBooking({ slug: 'maria', startsInMinutes: 50 * HOUR });
const urls = [`${base}/maria`, `${base}/m/${token}`];

if (chrome === null) {
  process.stdout.write(
    [
      'lighthouse: no Chrome found (CHROME_PATH unset, no Playwright Chromium, no Google Chrome). Skipped.',
      'To run it yourself, with Chrome installed:',
      '  cd web && npm run build:e2e && npx playwright install chromium && npm run lighthouse',
      'or point CHROME_PATH at a Chrome binary.',
      '',
    ].join('\n'),
  );
  await mock.close();
  process.exit(process.env['LIGHTHOUSE_REQUIRED'] === '1' ? 1 : 0);
}

process.stdout.write(`lighthouse: ${urls.join(' ')} with ${chrome}\n`);
// The mock serves from this very process, so lhci must run asynchronously: a spawnSync here would block the event loop
// and Lighthouse would wait on a page that never answers (NO_FCP after a protocol timeout).
const status = await new Promise<number>((done) => {
  const child = spawn('npx', ['--yes', `@lhci/cli@${LHCI_VERSION}`, 'autorun', '--config=lighthouserc.json', ...urls.map((url) => `--collect.url=${url}`)], {
    cwd: web,
    stdio: 'inherit',
    env: { ...process.env, CHROME_PATH: chrome },
  });
  child.on('exit', (code) => {
    done(code ?? 1);
  });
  child.on('error', () => {
    done(1);
  });
});
await mock.close();
printSummary();
process.exit(status);

/** One line per page: the median of the runs, so the log and the stage notes carry the numbers (the token is cut). */
function printSummary(): void {
  try {
    const manifest = JSON.parse(readFileSync(resolve(web, '.lighthouseci', 'reports', 'manifest.json'), 'utf8')) as {
      url: string;
      summary: Record<string, number>;
    }[];
    const byPage = new Map<string, Record<string, number>[]>();
    for (const run of manifest) {
      const page = new URL(run.url).pathname.replace(/^\/m\/[^/]+/, '/m/<token>');
      byPage.set(page, [...(byPage.get(page) ?? []), run.summary]);
    }
    for (const [page, runs] of byPage) {
      const median = (key: string): string => {
        const values = runs.map((run) => run[key] ?? 0).sort((a, b) => a - b);
        return (values[Math.floor(values.length / 2)] ?? 0).toFixed(2);
      };
      process.stdout.write(`lighthouse ${page}: performance ${median('performance')}, accessibility ${median('accessibility')}, best practices ${median('best-practices')} (median of ${String(runs.length)})\n`);
    }
  } catch {
    process.stdout.write('lighthouse: no manifest to summarise\n');
  }
}
