// What docs/10 section 10 and docs/06 section 6 promise about the page itself: strict headers, subresource
// integrity, nothing third-party, nothing professional-supplied rendered as markup, no cookie, and a published
// bundle hash that matches the files served. (The guard fixture in support.ts also watches EVERY test for a request
// to another origin, a CSP violation, a cookie and unexpected storage.)

import { createHash } from 'node:crypto';

import { expect, open, test } from './support';

test.describe('response headers', () => {
  test('the pages carry the strict policy, no cookie, and the right cache rules', async ({ request, mock, slugFor }) => {
    const { token, portalToken } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: 50 * 60 });
    const page = await request.get('/maria');
    const headers = page.headers();
    expect(page.status()).toBe(200);

    const csp = headers['content-security-policy'] ?? '';
    for (const directive of ["default-src 'none'", "script-src 'self'", "style-src 'self'", "connect-src 'self'", "frame-ancestors 'none'", "base-uri 'none'", "object-src 'none'"]) {
      expect(csp, directive).toContain(directive);
    }
    // No way back in: no inline code, no eval, no wildcard, no remote host anywhere in the policy.
    expect(csp).not.toMatch(/unsafe-inline|unsafe-eval|\*|https?:/);
    expect(headers['x-content-type-options']).toBe('nosniff');
    expect(headers['x-frame-options']).toBe('DENY');
    expect(headers['referrer-policy']).toBe('no-referrer');
    expect(headers['strict-transport-security']).toMatch(/max-age=\d{8,}/);
    expect(headers['permissions-policy']).toMatch(/camera=\(\)/);
    expect(headers['permissions-policy']).toMatch(/geolocation=\(\)/);
    expect(headers['cross-origin-opener-policy']).toBe('same-origin');
    expect(headers['set-cookie']).toBeUndefined();

    // A page that carries a secret link is never cached or indexed.
    for (const path of [`/m/${token}`, `/p/${portalToken}`]) {
      const secret = await request.get(path);
      expect(secret.headers()['cache-control'], path).toBe('no-store');
      expect(secret.headers()['x-robots-tag'], path).toContain('noindex');
    }
    const api = await request.post('/api/getBooking', { data: { data: { token } } });
    expect(api.status()).toBe(200);
    expect(api.headers()['cache-control']).toBe('no-store');
    expect(api.headers()['set-cookie']).toBeUndefined();
  });

  test('hashed assets are immutable and the HTML is always revalidated', async ({ request }) => {
    const html = await (await request.get('/maria')).text();
    const asset = /src="(\/assets\/[^"]+\.js)"/.exec(html)?.[1];
    expect(asset).toBeDefined();
    const response = await request.get(asset ?? '/');
    expect(response.headers()['cache-control']).toContain('immutable');
    expect((await request.get('/maria')).headers()['cache-control']).toBe('no-cache');
  });

  test('a token is never accepted in a URL: every function is POST only (callable protocol)', async ({ request }) => {
    const response = await request.get('/api/getBooking?token=AAAAAAAAAAAAAAAAAAAAAA');
    expect(response.status()).toBe(405);
    const read = await request.get('/api/getPublicPage?slug=maria');
    expect(read.status()).toBe(405);
  });

  test('errors carry a stable code and never personal data', async ({ request }) => {
    const response = await request.post('/api/getBooking', { data: { data: { token: 'AAAAAAAAAAAAAAAAAAAAAA' } } });
    expect(response.status()).toBe(404);
    expect(await response.json()).toEqual({ error: { status: 'NOT_FOUND', message: 'NOT_FOUND' } });
  });
});

test.describe('the document', () => {
  test('loads only its own scripts and stylesheet, each with a Subresource Integrity hash, and has no inline code', async ({ request }) => {
    const html = await (await request.get('/maria')).text();
    const tags = [...html.matchAll(/<(script|link)\b[^>]*>/gi)].map((match) => match[0]);
    expect(tags.length).toBeGreaterThan(0);
    for (const tag of tags) {
      if (/rel="?(preload|icon)/.test(tag) && !/as="?(script|style)/.test(tag)) continue;
      if (/\bsrc=|rel="?stylesheet/.test(tag)) {
        expect(tag, tag).toMatch(/integrity="sha384-[A-Za-z0-9+/=]+"/);
        expect(tag, tag).not.toMatch(/(?:src|href)="(?:https?:)?\/\//);
      }
    }
    expect(html).not.toMatch(/<script(?![^>]*\bsrc=)[^>]*>/i);
    expect(html).not.toMatch(/<style/i);
    expect(html).not.toMatch(/\son[a-z]+=/i);
    expect(html).toMatch(/<meta name="referrer" content="no-referrer"/);
  });

  test('the browser accepts every integrity hash (a wrong one would leave a blank page)', async ({ page, slugFor }) => {
    await open(page, `/${slugFor('maria')}`);
    await expect(page.getByTestId('book')).toBeVisible();
  });

  test('the published bundle hash list matches the files that are served', async ({ request }) => {
    const list = await (await request.get('/.well-known/bellohub-build.txt')).text();
    const rows = list.split('\n').filter((line) => /^[0-9a-f]{64} {2}/.test(line));
    expect(rows.length).toBeGreaterThan(5);
    for (const row of rows.filter((line) => /\.(js|css)$/.test(line)).slice(0, 8)) {
      const [hash, path] = row.split('  ');
      // The mock gzips on the wire; Playwright decodes it, so the bytes compared are the file's.
      const body = await (await request.get(`/${path ?? ''}`)).body();
      expect(createHash('sha256').update(body).digest('hex'), path).toBe(hash);
    }
    expect(list).toMatch(/bundle {2}sha256:[0-9a-f]{64}/);
  });
});

test.describe('professional-supplied text is data, never markup', () => {
  test('a name, headline and bio full of HTML are shown as text and nothing runs', async ({ page, slugFor }) => {
    const slug = slugFor('maria');
    await page.route('**/api/getPublicPage*', async (route) => {
      const response = await route.fetch();
      const json = (await response.json()) as { result: { profile: Record<string, unknown> } };
      const evil = '<img src=x onerror="window.__xss=1"><script>window.__xss=2</script>';
      const profile = json.result.profile;
      profile['displayName'] = `Maria ${evil}`;
      profile['businessName'] = evil;
      profile['bio'] = `<b>bold</b> ${evil}`;
      profile['city'] = evil;
      profile['rulesText'] = { en: evil, 'pt-BR': evil };
      profile['credentials'] = [{ title: evil, institution: evil }];
      await route.fulfill({ response, json });
    });
    await open(page, `/${slug}`);
    await expect(page.getByTestId('book')).toBeVisible();
    expect(await page.evaluate(() => (window as unknown as { __xss?: number }).__xss)).toBeUndefined();
    // The markup is on the page as characters, not as elements.
    expect(await page.locator('main img[src="x"], main script').count()).toBe(0);
    expect(await page.locator('main b', { hasText: /^bold$/ }).count()).toBe(0);
    await expect(page.locator('main')).toContainText('<img src=x');
  });

  test('a photo that is not a small data image is not loaded from anywhere', async ({ page, guard, slugFor }) => {
    await page.route('**/api/getPublicPage*', async (route) => {
      const response = await route.fetch();
      const json = (await response.json()) as { result: { profile: Record<string, unknown> } };
      json.result.profile['photo'] = 'https://tracker.example/pixel.png';
      await route.fulfill({ response, json });
    });
    await open(page, `/${slugFor('maria')}`);
    await expect(page.getByTestId('book')).toBeVisible();
    expect(guard.requests.filter((request) => request.url.includes('tracker.example'))).toEqual([]);
  });

  test('links that leave the page open with no referrer and no opener', async ({ page, mock, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: 50 * 60 });
    await open(page, `/m/${token}`);
    await expect(page.getByTestId('message-pro')).toBeVisible();
    const links = page.locator('a[href^="https://"]');
    const count = await links.count();
    expect(count).toBeGreaterThan(0);
    for (let index = 0; index < count; index += 1) {
      const rel = (await links.nth(index).getAttribute('rel')) ?? '';
      expect(rel).toContain('noopener');
      expect(rel).toContain('noreferrer');
    }
  });
});

test.describe('nothing leaves the allowed origins', () => {
  test('a full booking, a sealed form and a data request talk to the page origin only @core', async ({ page, mock, guard, slugFor }) => {
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * 60 });
    await open(page, `/m/${token}/form`);
    await expect(page.getByTestId('submit-intake')).toBeVisible();
    await open(page, `/m/${token}/data`);
    await open(page, `/${slug}`);
    const origins = new Set(guard.requests.filter((request) => /^https?:/.test(request.url)).map((request) => new URL(request.url).origin));
    expect([...origins]).toEqual([new URL(page.url()).origin]);
  });
});
