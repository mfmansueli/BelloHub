// The HTTP side of the mock: the API under /api, the built page under everything else (with the headers of
// hosting.json, so the tests run against the Content-Security-Policy that will ship), and test controls under /__test.

import { gzipSync } from 'node:zlib';
import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { dirname, extname, join, normalize, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { MockApi, MockError } from './api';

const here = dirname(fileURLToPath(import.meta.url));
const webRoot = resolve(here, '../..');

const TYPES: Readonly<Record<string, string>> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
};

interface HostingFile {
  hosting: { headers: { source: string; headers: { key: string; value: string }[] }[] };
}

function loadHeaders(): { pattern: RegExp; headers: { key: string; value: string }[] }[] {
  const file = JSON.parse(readFileSync(join(webRoot, 'hosting.json'), 'utf8')) as HostingFile;
  return file.hosting.headers.map((rule) => ({
    pattern: new RegExp(`^${rule.source.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*\*/g, '\u0000').replace(/\*/g, '[^/]*').replace(/\u0000/g, '.*')}$`),
    headers: rule.headers,
  }));
}

async function readBody(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of request) {
    const buffer = chunk as Buffer;
    size += buffer.length;
    if (size > 8 * 1024 * 1024) throw new MockError('tooLarge', 413);
    chunks.push(buffer);
  }
  if (chunks.length === 0) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8')) as unknown;
  } catch {
    throw new MockError('invalidInput', 400);
  }
}

function send(response: ServerResponse, status: number, body: unknown): void {
  const text = JSON.stringify(body);
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  response.end(text);
}

type Json = Record<string, unknown>;

export interface MockServer {
  readonly server: Server;
  readonly api: MockApi;
  readonly port: number;
  close(): Promise<void>;
}

/** A POST-only function takes its token in the body, never in the URL (docs/06 section 5). */
const POST_ONLY = new Set(['getBooking', 'confirmPresence', 'reportLate', 'rescheduleBooking', 'requestReschedule', 'cancelBooking', 'rebook', 'getPortal', 'getFormContext', 'submitSealed', 'holdSlot', 'createBooking', 'joinWaitlist', 'findBookings', 'sendEmailCode', 'verifyEmailCode', 'sendSmsCode', 'verifySmsCode']);

export async function startMock(port: number, distDirectory: string | null): Promise<MockServer> {
  const api = new MockApi();
  await api.init();
  const headerRules = loadHeaders();

  async function handleApi(name: string, method: string, query: URLSearchParams, request: IncomingMessage, response: ServerResponse): Promise<void> {
    if (method === 'GET' && POST_ONLY.has(name)) throw new MockError('invalidInput', 405);
    const body: Json = method === 'POST' ? ((await readBody(request)) as Json) : {};
    switch (name) {
      case 'getPublicPage':
        return send(response, 200, api.getPublicPage(query.get('slug') ?? ''));
      case 'getSlots': {
        const params: Json = method === 'GET' ? { ...Object.fromEntries(query.entries()) } : body;
        return send(response, 200, api.getSlots(params));
      }
      case 'holdSlot':
        return send(response, 200, api.holdSlot(body));
      case 'sendSmsCode':
        return send(response, 200, api.sendCode('sms', body));
      case 'verifySmsCode':
        return send(response, 200, api.verifyCode('sms', body));
      case 'sendEmailCode':
        return send(response, 200, api.sendCode('email', body));
      case 'verifyEmailCode':
        return send(response, 200, api.verifyCode('email', body));
      case 'createBooking':
        return send(response, 200, api.createBooking(body as never));
      case 'joinWaitlist':
        api.joinWaitlist(body);
        return send(response, 200, { ok: true });
      case 'findBookings':
        return send(response, 200, api.findBookings(body));
      case 'getBooking':
        return send(response, 200, api.getBooking(String(body['token'])));
      case 'confirmPresence':
        api.confirmPresence(String(body['token']));
        return send(response, 200, { ok: true });
      case 'reportLate':
        return send(response, 200, api.reportLate(String(body['token']), Number(body['minutes'])));
      case 'rescheduleBooking':
        return send(response, 200, api.rescheduleBooking(body));
      case 'requestReschedule':
        return send(response, 200, api.requestReschedule(body));
      case 'cancelBooking':
        return send(response, 200, api.cancelBooking(body));
      case 'rebook':
        return send(response, 200, api.rebook(body));
      case 'getPortal':
        return send(response, 200, api.getPortal(String(body['token'])));
      case 'getFormContext':
        return send(response, 200, api.getFormContext(String(body['token'])));
      case 'submitSealed':
        await api.submitSealed(body);
        return send(response, 200, { ok: true });
      default:
        throw new MockError('notFound', 404);
    }
  }

  async function handleTest(path: string, method: string, query: URLSearchParams, request: IncomingMessage, response: ServerResponse): Promise<void> {
    const body: Json = method === 'POST' ? ((await readBody(request)) as Json) : {};
    switch (path) {
      case '/__test/reset':
        api.reset();
        return send(response, 200, { ok: true });
      case '/__test/seed':
        return send(response, 200, api.seedBooking(body as never));
      case '/__test/seed-portal':
        return send(response, 200, { portalToken: api.seedPortal(String(body['slug']), String(body['name'] ?? 'Ana'), String(body['phone'] ?? '+5511987654321'), (body['mode'] as 'direct' | 'approval' | 'paused' | undefined) ?? 'direct') });
      case '/__test/seed-expired':
        return send(response, 200, { token: api.seedExpired(String(body['slug'])) });
      case '/__test/config':
        if (typeof body['resendAfterSeconds'] === 'number') api.resendAfterSeconds = body['resendAfterSeconds'];
        if (typeof body['failNext'] === 'object' && body['failNext'] !== null) {
          const fail = body['failNext'] as { name: string; code: string; status: number; times?: number };
          api.failNext(fail.name, fail.code, fail.status, fail.times ?? 1);
        }
        return send(response, 200, { ok: true });
      case '/__test/inbox':
        return send(response, 200, { items: api.inbox.filter((item) => query.get('slug') === null || item.slug === query.get('slug')) });
      case '/__test/bookings':
        return send(response, 200, { items: api.listBookings(query.get('slug') ?? '') });
      case '/__test/waitlist':
        return send(response, 200, { items: api.waitlist });
      case '/__test/requests':
        return send(response, 200, { items: api.rescheduleRequests });
      default:
        throw new MockError('notFound', 404);
    }
  }

  function serveStatic(url: URL, acceptEncoding: string, response: ServerResponse): void {
    if (distDirectory === null) {
      response.writeHead(404, { 'Content-Type': 'text/plain' });
      response.end('no build');
      return;
    }
    const requested = normalize(decodeURIComponent(url.pathname)).replace(/^(\.\.[/\\])+/, '');
    let file = join(distDirectory, requested);
    const isAsset = /\.[a-z0-9]+$/i.test(requested);
    if (!file.startsWith(distDirectory) || !existsSync(file) || statSync(file).isDirectory()) {
      if (isAsset) {
        response.writeHead(404, { 'Content-Type': 'text/plain' });
        response.end('not found');
        return;
      }
      file = join(distDirectory, 'index.html');
    }
    const headers: Record<string, string> = { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream' };
    for (const rule of headerRules) {
      if (rule.pattern.test(url.pathname)) for (const header of rule.headers) headers[header.key] = header.value;
    }
    // Firebase Hosting compresses text; the mock does the same so the throttled-network tests measure what ships.
    const compressible = /\.(html|js|css|json|svg|txt)$/.test(file);
    if (compressible && /\bgzip\b/.test(acceptEncoding)) {
      headers['Content-Encoding'] = 'gzip';
      headers['Vary'] = 'Accept-Encoding';
      response.writeHead(200, headers);
      response.end(gzipSync(readFileSync(file)));
      return;
    }
    response.writeHead(200, headers);
    response.end(readFileSync(file));
  }

  const server = createServer((request, response) => {
    const url = new URL(request.url ?? '/', 'http://localhost');
    const method = request.method ?? 'GET';
    const run = async (): Promise<void> => {
      if (url.pathname.startsWith('/api/')) return handleApi(url.pathname.slice(5), method, url.searchParams, request, response);
      if (url.pathname.startsWith('/__test/')) return handleTest(url.pathname, method, url.searchParams, request, response);
      serveStatic(url, request.headers['accept-encoding'] ?? '', response);
    };
    run().catch((error: unknown) => {
      if (error instanceof MockError) {
        send(response, error.status, { error: { code: error.code, ...error.extra } });
      } else {
        send(response, 500, { error: { code: 'server' } });
      }
    });
  });
  await new Promise<void>((done) => server.listen(port, '127.0.0.1', done));
  return {
    server,
    api,
    port,
    close: () =>
      new Promise<void>((done) => {
        server.closeAllConnections();
        server.close(() => { done(); });
      }),
  };
}
