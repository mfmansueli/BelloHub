import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { USE_CASES } from '../../src/app/registry.js';
import { FUNCTIONS_REGION } from '../../src/config/region.js';

const read = (relative: string): unknown => JSON.parse(readFileSync(fileURLToPath(new URL(`../../../${relative}`, import.meta.url)), 'utf8'));

interface Header {
  key: string;
  value: string;
}

interface Hosting {
  public: string;
  predeploy?: string[];
  headers: { source: string; headers: Header[] }[];
  rewrites: ({ source: string; function: { functionId: string; region: string } } | { source: string; destination: string })[];
}

/**
 * The web app is served by Firebase Hosting from the same `firebase.json` the functions deploy with; every public and token
 * function is reachable as `/api/<name>` on the page's own origin (API.md section 1, "Same-origin option"). The mock server
 * and the Playwright suite read `web/hosting.json`, so the two files must say the same thing.
 */
describe('the Hosting block of firebase.json', () => {
  const hosting = (read('firebase.json') as { hosting: Hosting }).hosting;
  const fragment = (read('../web/hosting.json') as { hosting: Hosting }).hosting;

  const functionRewrites = hosting.rewrites.filter((rewrite): rewrite is Extract<Hosting['rewrites'][number], { function: unknown }> => 'function' in rewrite);
  const rewritten = functionRewrites.map((rewrite) => rewrite.function.functionId);

  it('serves the production build of web/ and builds it first', () => {
    expect(hosting.public).toBe('../web/dist');
    expect(hosting.predeploy).toEqual(['npm --prefix ../web ci --no-audit --no-fund', 'npm --prefix ../web run build']);
  });

  it('rewrites /api/<name> to every public and token function plus getIcs, in the functions region, and nothing else', () => {
    const webFacing = USE_CASES.filter((useCase) => useCase.access === 'public' || useCase.access === 'token').map((useCase) => useCase.name);
    expect([...rewritten].sort()).toEqual([...webFacing, 'getIcs'].sort());
    for (const rewrite of functionRewrites) {
      expect(rewrite.source).toBe(`/api/${rewrite.function.functionId}`);
      expect(rewrite.function.region).toBe(FUNCTIONS_REGION);
    }
    // No owner function is exposed on the web origin: the iPhone calls them through the Functions SDK.
    const owner = USE_CASES.filter((useCase) => useCase.access === 'owner').map((useCase) => useCase.name);
    expect(rewritten.filter((name) => owner.includes(name))).toEqual([]);
  });

  it('sends everything else to index.html, as the last rule', () => {
    expect(hosting.rewrites.at(-1)).toEqual({ source: '**', destination: '/index.html' });
  });

  it('ships the headers the web tests run against (web/hosting.json), including the strict CSP and immutable assets', () => {
    expect(hosting.headers).toEqual(fragment.headers);
    const everywhere = hosting.headers.find((rule) => rule.source === '**')?.headers ?? [];
    const csp = everywhere.find((header) => header.key === 'Content-Security-Policy')?.value ?? '';
    expect(csp).toContain("default-src 'none'");
    expect(csp).toContain("connect-src 'self'");
    expect(csp).not.toMatch(/unsafe-|\*/);
    expect(everywhere.map((header) => header.key)).toEqual(
      expect.arrayContaining(['Strict-Transport-Security', 'X-Content-Type-Options', 'X-Frame-Options', 'Referrer-Policy', 'Permissions-Policy'])
    );
    const assets = hosting.headers.find((rule) => rule.source === '/assets/**')?.headers ?? [];
    expect(assets).toEqual([{ key: 'Cache-Control', value: 'public, max-age=31536000, immutable' }]);
    for (const source of ['/m/**', '/p/**', '/api/**']) {
      const rule = hosting.headers.find((candidate) => candidate.source === source)?.headers ?? [];
      expect(rule, source).toContainEqual({ key: 'Cache-Control', value: 'no-store' });
    }
  });

  it('keeps the web fragment in step with the deployed rewrites (the mock serves what ships)', () => {
    const fragmentFunctions = fragment.rewrites.filter((rewrite) => 'function' in rewrite).map((rewrite) => (rewrite as { function: { functionId: string } }).function.functionId);
    // The fragment may leave out functions the page never calls (getHold, getIcs); it may not name one that is not deployed.
    for (const name of fragmentFunctions) expect(rewritten).toContain(name);
    expect(fragment.rewrites.at(-1)).toEqual({ source: '**', destination: '/index.html' });
  });

  it('does not touch the prod target, which stays deny-all without Hosting', () => {
    const prod = read('firebase.prod.json') as { hosting?: unknown; firestore: { rules: string } };
    expect(prod.hosting).toBeUndefined();
    expect(prod.firestore.rules).toMatch(/^rules\/prod\//);
  });
});
