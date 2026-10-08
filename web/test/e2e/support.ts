// Shared fixtures of the end-to-end tests.
//
//   mock     the test controls of the mock API (seed a booking, read what the "server" holds)
//   slugFor  a professional of its own for this test, so parallel tests never share bookings
//   guard    runs around EVERY test and fails it when the page breaks a promise of docs/10 section 10:
//            a request to another origin, a cookie, a CSP violation, an uncaught error, or anything in browser
//            storage besides the chosen language and the non-clinical booking draft

import { test as base, expect, type APIRequestContext, type Page } from '@playwright/test';

export { expect };

export interface Options {
  /** Throttle the CPU four times and the network to slow 4G (Chromium only). */
  readonly lowEnd: boolean;
}

export interface SeedInput {
  readonly slug: string;
  readonly startsInMinutes: number;
  readonly status?: 'confirmed' | 'pendingApproval' | 'completed' | 'cancelledByClient' | 'cancelledByPro' | 'declined' | 'noShow';
  readonly serviceId?: string;
  readonly phone?: string;
  readonly name?: string;
  readonly rescheduleCount?: number;
  readonly intake?: 'pending' | 'done';
  readonly guests?: number;
  readonly checkIn?: boolean;
  readonly policy?: Record<string, unknown>;
}

export interface Seeded {
  readonly token: string;
  readonly bookingId: string;
  readonly portalToken: string;
}

export interface StoredBookingView {
  readonly id: string;
  readonly status: string;
  readonly serviceId: string;
  readonly addOnIds: string[];
  readonly guestNames: string[];
  readonly startsAt: string;
  readonly totalMinutes: number;
  readonly client: { name: string; phone: string; email?: string; locale: string };
  readonly rescheduleCount: number;
  readonly clientConfirmedAt: string | null;
  readonly lateByMinutes: number | null;
  readonly intake: string;
}

export interface InboxItem {
  readonly slug: string;
  readonly bookingId: string;
  readonly kind: string;
  readonly itemId: string;
  readonly payload: Record<string, unknown>;
  readonly sizeBytes: number;
}

export class Mock {
  constructor(private readonly request: APIRequestContext) {}

  private async post<T>(path: string, body: unknown): Promise<T> {
    const response = await this.request.post(path, { data: body });
    expect(response.ok(), `${path} -> ${response.status()}`).toBe(true);
    return (await response.json()) as T;
  }

  private async get<T>(path: string): Promise<T> {
    const response = await this.request.get(path);
    expect(response.ok(), `${path} -> ${response.status()}`).toBe(true);
    return (await response.json()) as T;
  }

  seed(input: SeedInput): Promise<Seeded> {
    return this.post<Seeded>('/__test/seed', input);
  }

  async seedPortal(slug: string, name = 'Ana', phone = '+5511987654321', mode: 'direct' | 'approval' | 'paused' = 'direct'): Promise<string> {
    return (await this.post<{ portalToken: string }>('/__test/seed-portal', { slug, name, phone, mode })).portalToken;
  }

  async seedExpired(slug: string): Promise<string> {
    return (await this.post<{ token: string }>('/__test/seed-expired', { slug })).token;
  }

  async bookings(slug: string): Promise<StoredBookingView[]> {
    return (await this.get<{ items: StoredBookingView[] }>(`/__test/bookings?slug=${slug}`)).items;
  }

  async inbox(slug: string): Promise<InboxItem[]> {
    return (await this.get<{ items: InboxItem[] }>(`/__test/inbox?slug=${slug}`)).items;
  }

  async waitlist(slug: string): Promise<Record<string, unknown>[]> {
    return (await this.get<{ items: Record<string, unknown>[] }>('/__test/waitlist')).items.filter((item) => item['slug'] === slug);
  }

  async rescheduleRequests(slug: string): Promise<Record<string, unknown>[]> {
    return (await this.get<{ items: Record<string, unknown>[] }>('/__test/requests')).items.filter((item) => item['slug'] === slug);
  }
}

export interface SeenRequest {
  readonly url: string;
  readonly method: string;
  readonly body: string | null;
}

export interface Guard {
  /** Every request the browser made during this test. */
  readonly requests: SeenRequest[];
  /** Skip the storage assertion for a test that checks storage itself. */
  allowStorage(keys: RegExp): void;
}

interface Fixtures {
  readonly mock: Mock;
  readonly slugFor: (scenario: string) => string;
  readonly guard: Guard;
}

declare global {
  interface Window {
    __cspViolations?: string[];
  }
}

const SILENT_SCHEMES = /^(data|blob|about):/;

export const test = base.extend<Fixtures & Options>({
  lowEnd: [false, { option: true }],

  mock: async ({ request }, use) => {
    await use(new Mock(request));
  },

  // Playwright wants a destructuring pattern as the first argument, even when no fixture is used.
  // eslint-disable-next-line no-empty-pattern
  slugFor: async ({}, use, testInfo) => {
    // One short random tail per test: `maria-approval-tw2k7q4`. The mock reads "-t<id>" as "same professional,
    // private bookings".
    const tail = `t${testInfo.workerIndex}${Math.random().toString(36).slice(2, 6)}`;
    await use((scenario) => `${scenario}-${tail}`);
  },

  page: async ({ page, lowEnd, browserName }, use) => {
    if (lowEnd && browserName === 'chromium') {
      const session = await page.context().newCDPSession(page);
      await session.send('Emulation.setCPUThrottlingRate', { rate: 4 });
      await session.send('Network.enable');
      await session.send('Network.emulateNetworkConditions', {
        offline: false,
        latency: 150,
        downloadThroughput: (1.6 * 1024 * 1024) / 8,
        uploadThroughput: (750 * 1024) / 8,
      });
    }
    await use(page);
  },

  guard: [
    async ({ context, baseURL }, use) => {
      const requests: SeenRequest[] = [];
      const problems: string[] = [];
      const storageAllowed: RegExp[] = [/^bh\.lang$/, /^bh\.draft\./];
      const origin = new URL(baseURL ?? 'http://127.0.0.1:4010').origin;

      await context.addInitScript(() => {
        window.__cspViolations = [];
        document.addEventListener('securitypolicyviolation', (event) => {
          window.__cspViolations?.push(`${event.violatedDirective} ${event.blockedURI} ${event.sample} ${event.sourceFile}:${event.lineNumber}`);
        });
      });
      context.on('request', (request) => {
        requests.push({ url: request.url(), method: request.method(), body: request.postData() });
        if (!SILENT_SCHEMES.test(request.url()) && new URL(request.url()).origin !== origin) problems.push(`request left the allowed origins: ${request.url()}`);
      });
      context.on('console', (message) => {
        if (message.type() === 'error' && /content security policy|refused to/i.test(message.text())) problems.push(`CSP: ${message.text()}`);
      });
      context.on('weberror', (error) => {
        problems.push(`uncaught error in the page: ${error.error().message}`);
      });

      const guard: Guard = {
        requests,
        allowStorage: (keys) => {
          storageAllowed.push(keys);
        },
      };
      await use(guard);

      for (const page of context.pages()) {
        if (page.isClosed() || !page.url().startsWith('http')) continue;
        try {
          const state = await page.evaluate(() => ({
            violations: window.__cspViolations ?? [],
            local: Object.keys(window.localStorage),
            session: Object.keys(window.sessionStorage),
            cookie: document.cookie,
          }));
          for (const violation of state.violations) problems.push(`CSP violation: ${violation}`);
          for (const key of [...state.local, ...state.session]) {
            if (!storageAllowed.some((allowed) => allowed.test(key))) problems.push(`browser storage holds ${key}`);
          }
          if (state.cookie !== '') problems.push('document.cookie is not empty');
        } catch {
          // A page that is navigating or crashed has nothing left to inspect.
        }
      }
      const cookies = await context.cookies();
      if (cookies.length > 0) problems.push(`cookies were set: ${cookies.map((cookie) => cookie.name).join(', ')}`);
      expect(problems, 'promises of docs/10 section 10').toEqual([]);
    },
    { auto: true },
  ],
});

// MARK: Page helpers

/** Waits for the app to render its first screen. */
export async function ready(page: Page): Promise<void> {
  await expect(page.locator('main')).toBeVisible();
}

export async function open(page: Page, path: string): Promise<void> {
  await page.goto(path);
  await ready(page);
}

/** A checkbox or radio inside a styled label is visually replaced; the label is what a finger taps. */
export async function tap(page: Page, testId: string): Promise<void> {
  const target = page.getByTestId(testId);
  const tag = await target.evaluate((element) => element.tagName.toLowerCase() + ':' + (element as HTMLInputElement).type);
  if (tag === 'input:checkbox' || tag === 'input:radio') await page.locator('label', { has: target }).click();
  else await target.click();
}

export async function noHorizontalScroll(page: Page): Promise<void> {
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(overflow, 'horizontal overflow in px').toBeLessThanOrEqual(0);
}

/** The visible text of the main area, for assertions that must not depend on layout. */
export async function mainText(page: Page): Promise<string> {
  return (await page.locator('main').innerText()).replace(/\s+/g, ' ');
}
