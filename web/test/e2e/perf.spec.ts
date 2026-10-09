// A client on an inexpensive Android phone and a slow link (docs/10 section 8): the "low-end" project throttles the
// CPU four times and the network to 1.6 Mbit/s with 150 ms latency, and these budgets must hold there. They are
// looser than a desktop's on purpose and tighter than what a person tolerates before leaving.

import { expect, open, test } from './support';

interface Metrics {
  readonly lcp: number;
  readonly fcp: number;
  readonly cls: number;
  readonly blocking: number;
  readonly scriptBytes: number;
  readonly cssBytes: number;
  readonly fontBytes: number;
  readonly requests: number;
}

const BUDGET = {
  /** Largest Contentful Paint, ms. "Good" is 2500; the page measured about 2100 here, so this leaves room for a noisy machine. */
  lcp: 3000,
  /** Cumulative Layout Shift. */
  cls: 0.05,
  /** Time the main thread was blocked by tasks over 50 ms, ms. */
  blocking: 600,
  /** Compressed bytes of JavaScript fetched before the first screen. */
  scriptBytes: 80 * 1024,
  cssBytes: 15 * 1024,
  fontBytes: 60 * 1024,
} as const;

test.describe('performance on a low-end phone @perf', () => {
  test('the professional page paints fast, does not jump, and stays inside its byte budget', async ({ page, slugFor }, testInfo) => {
    await page.addInitScript(() => {
      const state = { lcp: 0, fcp: 0, cls: 0, blocking: 0 };
      (window as unknown as { __metrics: typeof state }).__metrics = state;
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) state.lcp = entry.startTime;
      }).observe({ type: 'largest-contentful-paint', buffered: true });
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) if (entry.name === 'first-contentful-paint') state.fcp = entry.startTime;
      }).observe({ type: 'paint', buffered: true });
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries() as unknown as { hadRecentInput: boolean; value: number }[]) if (!entry.hadRecentInput) state.cls += entry.value;
      }).observe({ type: 'layout-shift', buffered: true });
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) state.blocking += Math.max(0, entry.duration - 50);
      }).observe({ type: 'longtask', buffered: true });
    });

    await open(page, `/${slugFor('maria')}`);
    await expect(page.getByTestId('book')).toBeVisible();
    // The observers deliver their entries after the paint: wait for the largest paint to be reported.
    await expect.poll(() => page.evaluate(() => (window as unknown as { __metrics: { lcp: number } }).__metrics.lcp)).toBeGreaterThan(0);
    await page.evaluate(() => new Promise<void>((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => { resolve(); }))));

    const metrics = await page.evaluate<Metrics>(() => {
      const state = (window as unknown as { __metrics: { lcp: number; fcp: number; cls: number; blocking: number } }).__metrics;
      const resources = performance.getEntriesByType('resource') as PerformanceResourceTiming[];
      const bytes = (pattern: RegExp): number => resources.filter((entry) => pattern.test(new URL(entry.name).pathname)).reduce((sum, entry) => sum + entry.encodedBodySize, 0);
      return { ...state, scriptBytes: bytes(/\.js$/), cssBytes: bytes(/\.css$/), fontBytes: bytes(/\.woff2$/), requests: resources.length };
    });
    await testInfo.attach('metrics.json', { body: JSON.stringify(metrics, null, 2), contentType: 'application/json' });
    // One line in the log, so a regression is visible before it crosses a budget.
    process.stdout.write(`perf ${testInfo.project.name}: lcp=${Math.round(metrics.lcp)}ms cls=${metrics.cls.toFixed(3)} blocking=${Math.round(metrics.blocking)}ms js=${(metrics.scriptBytes / 1024).toFixed(1)}KB css=${(metrics.cssBytes / 1024).toFixed(1)}KB fonts=${(metrics.fontBytes / 1024).toFixed(1)}KB requests=${metrics.requests}\n`);

    expect(metrics.lcp, 'Largest Contentful Paint (ms)').toBeLessThan(BUDGET.lcp);
    expect(metrics.cls, 'Cumulative Layout Shift').toBeLessThan(BUDGET.cls);
    expect(metrics.blocking, 'blocking time of long tasks (ms)').toBeLessThan(BUDGET.blocking);
    expect(metrics.scriptBytes, 'JavaScript before the first screen (compressed bytes)').toBeLessThan(BUDGET.scriptBytes);
    expect(metrics.cssBytes, 'CSS (compressed bytes)').toBeLessThan(BUDGET.cssBytes);
    expect(metrics.fontBytes, 'fonts (bytes)').toBeLessThan(BUDGET.fontBytes);
  });

  test('the sealing library is not part of the first load; it arrives when the form is sent', async ({ page, mock, guard, slugFor }) => {
    const { token } = await mock.seed({ slug: slugFor('maria'), startsInMinutes: 50 * 60 });
    await open(page, `/${slugFor('maria')}`);
    await expect(page.getByTestId('book')).toBeVisible();
    const early = guard.requests.filter((request) => /\/assets\/seal-/.test(request.url));
    expect(early, 'the sealing chunk before any form').toEqual([]);
    await open(page, `/m/${token}/form`);
    await expect(page.getByTestId('submit-intake')).toBeVisible();
    expect(guard.requests.filter((request) => /\/assets\/seal-/.test(request.url)), 'still not fetched on opening the form').toEqual([]);
  });

  test('booking, rescheduling and cancelling still work on the throttled phone', async ({ page, mock, slugFor }) => {
    test.slow();
    const slug = slugFor('maria');
    const { token } = await mock.seed({ slug, startsInMinutes: 50 * 60 });
    await open(page, `/m/${token}/reschedule`);
    const slots = page.locator('[data-testid^="slot-"]');
    await expect(slots.first()).toBeVisible();
    await slots.nth(1).click();
    await page.getByTestId('confirm-reschedule').click();
    await expect(page.getByTestId('done-text')).toBeVisible();
    await open(page, `/m/${token}/cancel`);
    await page.getByTestId('confirm-cancel').click();
    await expect(page.getByTestId('done-text')).toBeVisible();
    expect((await mock.bookings(slug))[0]?.status).toBe('cancelledByClient');
  });
});
