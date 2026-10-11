// `npm run mock`: the mock API on port 4010 (development, with `npm run dev` proxying /api to it), or, with
// `--serve-dist`, the production build too, with the production headers. Playwright starts it that way.

import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { startMock } from './server';

const here = dirname(fileURLToPath(import.meta.url));
const flag = process.argv.indexOf('--serve-dist');
const serveDist = flag >= 0;
// `--serve-dist [directory]`: the production build (default dist/) or the build made for the tests (dist-e2e/).
const given = flag >= 0 ? process.argv[flag + 1] : undefined;
const dist = resolve(here, '../..', given !== undefined && !given.startsWith('--') ? given : 'dist');
const port = Number(process.env['PORT'] ?? 4010);

if (serveDist && !existsSync(resolve(dist, 'index.html'))) {
  process.stderr.write(`error: ${dist} is missing. Run: npm run build (or npm run build:e2e)\n`);
  process.exit(1);
}

const mock = await startMock(port, serveDist ? dist : null);
process.stdout.write(`mock API on http://127.0.0.1:${mock.port}${serveDist ? ' (serving dist with the hosting headers)' : ''}\n`);

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    void mock.close().then(() => process.exit(0));
  });
}
