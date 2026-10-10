// Fixtures of the end-to-end run against the real backend (playwright.e2e-local.config.ts).
//
//   store   reads what the functions wrote, through the Firestore emulator's REST API (the emulator accepts the
//           `Bearer owner` token and bypasses the rules; nothing here could work against a real project)
//   guard   the promises of docs/10 section 10 on every test: every request stays on the page's origin (the /api
//           rewrites), no CSP violation, no uncaught error, no cookie, nothing in storage but the language and the
//           non-clinical draft

import { test as base, expect, type Page } from '@playwright/test';

export { expect };

const PROJECT = 'demo-bellohub';
const FIRESTORE_HOST = process.env['E2E_FIRESTORE_HOST'] ?? '127.0.0.1:28080';

type Json = Record<string, unknown>;

interface RestValue {
  stringValue?: string;
  integerValue?: string;
  doubleValue?: number;
  booleanValue?: boolean;
  timestampValue?: string;
  nullValue?: null;
  mapValue?: { fields?: Record<string, RestValue> };
  arrayValue?: { values?: RestValue[] };
}

function decode(value: RestValue): unknown {
  if (value.stringValue !== undefined) return value.stringValue;
  if (value.integerValue !== undefined) return Number(value.integerValue);
  if (value.doubleValue !== undefined) return value.doubleValue;
  if (value.booleanValue !== undefined) return value.booleanValue;
  // The REST API prints whole seconds without the milliseconds; the page's instants always carry them.
  if (value.timestampValue !== undefined) return new Date(value.timestampValue).toISOString();
  if (value.mapValue !== undefined) return decodeFields(value.mapValue.fields ?? {});
  if (value.arrayValue !== undefined) return (value.arrayValue.values ?? []).map(decode);
  return null;
}

function decodeFields(fields: Record<string, RestValue>): Json {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decode(value)]));
}

export interface StoredDoc {
  readonly id: string;
  readonly data: Json;
}

export class Store {
  /** Every document of a collection (or subcollection) path, decoded. */
  async list(path: string): Promise<StoredDoc[]> {
    const response = await fetch(`http://${FIRESTORE_HOST}/v1/projects/${PROJECT}/databases/(default)/documents/${path}?pageSize=300`, {
      headers: { Authorization: 'Bearer owner' },
    });
    expect(response.ok, `firestore emulator ${path} -> ${response.status}`).toBe(true);
    const body = (await response.json()) as { documents?: { name: string; fields?: Record<string, RestValue> }[] };
    return (body.documents ?? []).map((document) => ({ id: document.name.slice(document.name.lastIndexOf('/') + 1), data: decodeFields(document.fields ?? {}) }));
  }

  async bookings(): Promise<StoredDoc[]> {
    return this.list('bookings');
  }

  async inbox(uid: string): Promise<StoredDoc[]> {
    return this.list(`inbox/${uid}/items`);
  }

  async outbox(): Promise<Json[]> {
    return (await this.list('emulatorOutbox')).map((document) => document.data);
  }

  /**
   * Replaces the busy stretches of her published availability, as the app's next `publishAvailability` would: visits
   * of her own agenda (no names) the page must work around.
   */
  async setBusy(uid: string, busy: readonly { start: string; end: string; kind: 'appointment' | 'block' }[]): Promise<void> {
    const values = busy.map((entry) => ({
      mapValue: { fields: { start: { timestampValue: entry.start }, end: { timestampValue: entry.end }, kind: { stringValue: entry.kind } } },
    }));
    const response = await fetch(`http://${FIRESTORE_HOST}/v1/projects/${PROJECT}/databases/(default)/documents/availability/${uid}?updateMask.fieldPaths=busy`, {
      method: 'PATCH',
      headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: { busy: { arrayValue: { values } } } }),
    });
    expect(response.ok, `firestore emulator availability/${uid} -> ${response.status}`).toBe(true);
  }
}

export interface SeenRequest {
  readonly url: string;
  readonly method: string;
  readonly body: string | null;
}

interface Fixtures {
  readonly store: Store;
  readonly requests: SeenRequest[];
}

export const test = base.extend<Fixtures>({
  // Playwright wants a destructuring pattern as the first argument, even when no fixture is used.
  // eslint-disable-next-line no-empty-pattern
  store: async ({}, use) => {
    await use(new Store());
  },

  requests: [
    async ({ context, baseURL }, use) => {
      const requests: SeenRequest[] = [];
      const problems: string[] = [];
      const origin = new URL(baseURL ?? 'http://127.0.0.1:25080').origin;

      await context.exposeBinding('__cspReport', (_source, report: { directive: string; blockedURI: string; source: string }) => {
        problems.push(`CSP violation: ${report.directive} ${report.blockedURI} ${report.source}`);
      });
      await context.addInitScript(() => {
        document.addEventListener('securitypolicyviolation', (event) => {
          const report = (window as unknown as { __cspReport?: (report: { directive: string; blockedURI: string; source: string }) => void }).__cspReport;
          report?.({ directive: event.violatedDirective, blockedURI: event.blockedURI, source: `${event.sourceFile}:${event.lineNumber}` });
        });
      });
      context.on('request', (request) => {
        requests.push({ url: request.url(), method: request.method(), body: request.postData() });
        if (!/^(data|blob|about):/.test(request.url()) && new URL(request.url()).origin !== origin) problems.push(`request left the page's origin: ${request.url()}`);
      });
      context.on('weberror', (error) => {
        problems.push(`uncaught error in the page: ${error.error().message}`);
      });

      await use(requests);

      for (const page of context.pages()) {
        if (page.isClosed() || !page.url().startsWith('http')) continue;
        try {
          const state = await page.evaluate(() => ({ keys: [...Object.keys(window.localStorage), ...Object.keys(window.sessionStorage)], cookie: document.cookie }));
          for (const key of state.keys) if (!/^bh\.(lang|draft\.)/.test(key)) problems.push(`browser storage holds ${key}`);
          if (state.cookie !== '') problems.push('document.cookie is not empty');
        } catch {
          // A page that is navigating or crashed has nothing left to inspect.
        }
      }
      expect((await context.cookies()).length, 'cookies').toBe(0);
      expect(problems, 'promises of docs/10 section 10').toEqual([]);
    },
    { auto: true },
  ],
});

// MARK: Page helpers

export async function open(page: Page, path: string): Promise<void> {
  await page.goto(path);
  await expect(page.locator('main')).toBeVisible();
}

/** A checkbox or radio inside a styled label is visually replaced; the label is what a finger taps. */
export async function tap(page: Page, testId: string): Promise<void> {
  const target = page.getByTestId(testId);
  const tag = await target.evaluate((element) => element.tagName.toLowerCase() + ':' + (element as HTMLInputElement).type);
  if (tag === 'input:checkbox' || tag === 'input:radio') await page.locator('label', { has: target }).click();
  else await target.click();
}

/** `YYYY-MM-DD` of an instant in a time zone (the calendar's day keys are in the professional's zone). */
export function dateKeyIn(zone: string, instant: number): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(instant));
}

/**
 * Picks the first bookable day at least `minDays` ahead (so the booking sits inside the free window and can be moved
 * and cancelled without a warning), moving the calendar forward when the day is in the next month.
 */
export async function chooseDayAhead(page: Page, zone: string, minDays: number, maxDays = 21): Promise<string> {
  // The month's days are disabled until its free times arrive from the server.
  const enabledDay = page.locator('[data-testid^="day-"]:not([aria-disabled="true"])').first();
  await expect(enabledDay).toBeVisible();
  for (let offset = minDays; offset <= maxDays; offset += 1) {
    const key = dateKeyIn(zone, Date.now() + offset * 86_400_000);
    let day = page.getByTestId(`day-${key}`);
    if ((await day.count()) === 0) {
      const next = page.getByTestId('cal-next');
      if ((await next.count()) === 0 || !(await next.isEnabled())) continue;
      await next.click();
      await expect(enabledDay).toBeVisible();
      day = page.getByTestId(`day-${key}`);
    }
    if ((await day.count()) === 0 || (await day.getAttribute('aria-disabled')) === 'true') continue;
    await day.click();
    // The time list of the day shown before the click stays on screen until the page re-renders, so a caller that
    // read `slots.first()` right away sometimes booked the previous day (the flake of S8). Wait until the chosen day
    // is the selected cell and every listed time falls on it in the business zone.
    await expect(page.locator(`[role="gridcell"][aria-selected="true"] [data-testid="day-${key}"]`)).toBeVisible();
    const slots = page.locator('[data-testid^="slot-"]');
    await expect
      .poll(async () => {
        const ids = await slots.evaluateAll((elements) => elements.map((element) => element.getAttribute('data-testid') ?? ''));
        return ids.length > 0 && ids.every((id) => dateKeyIn(zone, Date.parse(id.replace('slot-', ''))) === key);
      }, { message: `the free times of ${key}` })
      .toBe(true);
    return key;
  }
  throw new Error(`no bookable day between ${minDays} and ${maxDays} days ahead`);
}

/** Waits for a condition read from the store (never a fixed sleep): triggers run a moment after the write. */
export async function waitFor<T>(read: () => Promise<T | undefined | false>, what: string, timeoutMs = 30_000): Promise<T> {
  const started = Date.now();
  for (;;) {
    const value = await read();
    if (value !== undefined && value !== false) return value;
    if (Date.now() - started > timeoutMs) throw new Error(`timed out waiting for ${what}`);
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
}
