// The HTTP side of the mock: the API under /api (the callable protocol of API.md section 1: POST `{data}`, answers
// `{result}`, errors `{error:{status,message,details}}`), the built page under everything else (with the headers of
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
    if (size > 8 * 1024 * 1024) throw new MockError('PAYLOAD_TOO_LARGE', { maxBytes: 8 * 1024 * 1024 }, 413);
    chunks.push(buffer);
  }
  if (chunks.length === 0) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8')) as unknown;
  } catch {
    throw new MockError('INVALID_ARGUMENT');
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


export async function startMock(port: number, distDirectory: string | null): Promise<MockServer> {
  const api = new MockApi();
  await api.init();
  const headerRules = loadHeaders();

  /** Every function is a callable: POST only, `{ data }` in, `{ result }` out. A GET never reaches a function. */
  async function handleApi(name: string, method: string, request: IncomingMessage, response: ServerResponse): Promise<void> {
    if (method !== 'POST') throw new MockError('INVALID_ARGUMENT', undefined, 405);
    const envelope = (await readBody(request)) as Json;
    if (typeof envelope['data'] !== 'object' || envelope['data'] === null) throw new MockError('INVALID_ARGUMENT', { fields: ['data'] });
    const data = envelope['data'] as Json;
    const result = await callFunction(name, data);
    send(response, 200, { result });
  }

  async function callFunction(name: string, data: Json): Promise<unknown> {
    switch (name) {
      case 'getPublicPage':
        return api.getPublicPage(data);
      case 'getSlots':
        return api.getSlots(data);
      case 'holdSlot':
        return api.holdSlot(data);
      case 'sendSmsCode':
        return api.sendCode('phone', data);
      case 'verifySmsCode':
        return api.verifyCode('phone', data);
      case 'sendEmailCode':
        return api.sendCode('email', data);
      case 'verifyEmailCode':
        return api.verifyCode('email', data);
      case 'createBooking':
        return api.createBooking(data);
      case 'joinWaitlist':
        return api.joinWaitlist(data);
      case 'findBookings':
        return api.findBookings(data);
      case 'getBooking':
        return api.getBooking(data);
      case 'confirmPresence':
        return api.confirmPresence(data);
      case 'reportLate':
        return api.reportLate(data);
      case 'rescheduleBooking':
        return api.rescheduleBooking(data);
      case 'requestReschedule':
        return api.requestReschedule(data);
      case 'cancelBooking':
        return api.cancelBooking(data);
      case 'rebook':
        return api.rebook(data);
      case 'getPortal':
        return api.getPortal(data);
      case 'getFormContext':
        return api.getFormContext(data);
      case 'submitSealed':
        return api.submitSealed(data);
      default:
        throw new MockError('NOT_FOUND');
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
        throw new MockError('NOT_FOUND');
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
      if (url.pathname.startsWith('/api/')) return handleApi(url.pathname.slice(5), method, request, response);
      if (url.pathname.startsWith('/__test/')) return handleTest(url.pathname, method, url.searchParams, request, response);
      serveStatic(url, request.headers['accept-encoding'] ?? '', response);
    };
    run().catch((error: unknown) => {
      if (error instanceof MockError) {
        send(response, error.status, { error: { status: error.callableStatus, message: error.code, ...(error.details === undefined ? {} : { details: error.details }) } });
      } else {
        send(response, 500, { error: { status: 'INTERNAL', message: 'INTERNAL' } });
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
