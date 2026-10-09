// The wire protocol of firebase/functions/API.md as the page speaks it: callable envelopes, error codes, and the
// parsers that turn the server's shapes into what the screens render.

import { describe, expect, it } from 'vitest';

import { createApi } from '../../src/api/client';
import { ApiError } from '../../src/api/errors';
import { bookingView, parseHold, parsePublicPage, parseSlots, questionsOf, rulesFromText } from '../../src/api/parse';
import { createTransport, toError } from '../../src/api/transport';
import type { WireBooking, WireProfile } from '../../src/api/types';

function fakeFetch(handler: (url: string, init: RequestInit) => { status: number; body: unknown }): { fetch: typeof fetch; calls: { url: string; init: RequestInit }[] } {
  const calls: { url: string; init: RequestInit }[] = [];
  const impl = ((input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    const url = String(input);
    calls.push({ url, init: init ?? {} });
    const { status, body } = handler(url, init ?? {});
    return Promise.resolve(new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } }));
  }) as typeof fetch;
  return { fetch: impl, calls };
}

function profile(): WireProfile {
  return {
    schemaVersion: 1,
    slug: 'maria',
    displayName: 'Maria Beauty',
    regionCode: 'BR',
    timeZoneID: 'America/Sao_Paulo',
    currencyCode: 'BRL',
    locales: ['pt-BR', 'en'],
    credentials: [],
    services: [{ id: 'a', name: 'Glow', durationMinutes: 60, price: { display: 'show', amount: 70 } }],
    addOns: [],
    booking: { acceptingBookings: true, requiresApproval: false, maxGuests: 2, maxDaysAhead: 60 },
    policy: { freeWindowHours: 24, clientCanReschedule: true, afterWindowCancel: 'allow', afterWindowReschedule: 'request', askConfirmation: true, graceMinutes: 15 },
    rulesText: { en: 'Line one\n\n- Line two\n', 'pt-BR': 'Linha um' },
    inboxKey: { keyId: 'k', alg: 'hpke-v1', pub: 'p' },
    updatedAt: '2026-10-01T00:00:00.000Z',
  };
}

describe('callable transport (API.md section 1)', () => {
  it('POSTs { data } to <base>/<name> and unwraps { result }, with no token in the URL', async () => {
    const { fetch, calls } = fakeFetch(() => ({ status: 200, body: { result: { ok: true } } }));
    const transport = createTransport({ baseUrl: '/api', fetchImpl: fetch });
    await expect(transport.call('getBooking', { token: 'SECRET' })).resolves.toEqual({ ok: true });
    const [call] = calls;
    expect(call?.url).toBe('/api/getBooking');
    expect(call?.init.method).toBe('POST');
    expect(JSON.parse(String(call?.init.body))).toEqual({ data: { token: 'SECRET' } });
    // D46: no Firebase SDK in the page, so no App Check token header.
    expect(new Headers(call?.init.headers).has('X-Firebase-AppCheck')).toBe(false);
    expect(call?.init.credentials).toBe('omit');
    expect(call?.init.referrerPolicy).toBe('no-referrer');
  });

  it('a 2xx without { result } is a server fault', async () => {
    const { fetch } = fakeFetch(() => ({ status: 200, body: { ok: true } }));
    const transport = createTransport({ baseUrl: '/api', fetchImpl: fetch });
    await expect(transport.call('getPublicPage', { slug: 'x' })).rejects.toMatchObject({ code: 'server' });
  });

  it('maps the stable codes of section 3 onto the page vocabulary, and reads retryAfterSeconds from details', () => {
    const cases: [string, number, string][] = [
      ['NOT_FOUND', 404, 'notFound'],
      ['TOKEN_EXPIRED', 404, 'expired'],
      ['RATE_LIMITED', 429, 'rateLimited'],
      ['INVALID_CODE', 400, 'codeInvalid'],
      ['VERIFICATION_FAILED', 403, 'codeExpired'],
      ['NOT_ALLOWED', 400, 'notAllowed'],
      ['CONFIRMATION_REQUIRED', 400, 'notAllowed'],
      ['BOOKING_NOT_ACTIVE', 400, 'notAllowed'],
      ['PAYLOAD_TOO_LARGE', 400, 'tooLarge'],
      ['KEY_MISMATCH', 400, 'keyMismatch'],
      ['NOT_CONFIGURED', 503, 'unavailable'],
      ['TRY_AGAIN', 503, 'unavailable'],
      ['APP_CHECK_REQUIRED', 401, 'appCheck'],
      ['INVALID_ARGUMENT', 400, 'invalidInput'],
      ['INTERNAL', 500, 'server'],
    ];
    for (const [message, status, code] of cases) {
      expect(toError(status, { error: { status: 'X', message } }).code, message).toBe(code);
    }
    const limited = toError(429, { error: { status: 'RESOURCE_EXHAUSTED', message: 'RATE_LIMITED', details: { retryAfterSeconds: 42 } } });
    expect(limited.retryAfterSeconds).toBe(42);
    // An unknown code falls back to the status; a body without an error object too.
    expect(toError(404, { error: { message: 'SOMETHING_NEW' } }).code).toBe('notFound');
    expect(toError(503, null).code).toBe('unavailable');
  });
});

describe('parsers (API.md sections 4 and 5)', () => {
  it('turns getPublicPage into the page profile: first name, default language, rules as lines', () => {
    const page = parsePublicPage({ profile: profile(), intakeAvailable: true, features: { whatsAppAutomation: false, smsCallingCodes: ['55'] }, serverTime: '2026-10-01T00:00:00.000Z' });
    expect(page.firstName).toBe('Maria');
    expect(page.defaultLocale).toBe('pt-BR');
    expect(page.rules['en']).toEqual([{ text: 'Line one' }, { text: 'Line two' }]);
    expect(page.rules['pt-BR']).toEqual([{ text: 'Linha um' }]);
    expect(page.intakeAvailable).toBe(true);
    expect(page.features.smsCallingCodes).toEqual(['55']);
  });

  it('refuses a profile without the fields the page cannot render', () => {
    expect(() => parsePublicPage({ profile: { ...profile(), inboxKey: undefined }, intakeAvailable: false, features: {}, serverTime: 'x' })).toThrow(ApiError);
  });

  it('flattens the days of getSlots into one ascending list', () => {
    const slots = parseSlots({ timeZoneID: 'UTC', durationMinutes: 60, paused: false, days: [{ date: '2026-10-02', slots: ['2026-10-02T13:00:00.000Z'] }, { date: '2026-10-01', slots: ['2026-10-01T12:00:00.000Z', '2026-10-01T13:00:00.000Z'] }] });
    expect(slots.slots).toEqual(['2026-10-01T12:00:00.000Z', '2026-10-01T13:00:00.000Z', '2026-10-02T13:00:00.000Z']);
    expect(slots.durationMinutes).toBe(60);
  });

  it('a hold that is not granted is the error the time screen already handles', () => {
    expect(parseHold({ status: 'held', holdId: 'h', expiresAt: 'e' })).toEqual({ holdId: 'h', expiresAt: 'e' });
    expect(() => parseHold({ status: 'slotTaken', alternatives: [] })).toThrow(expect.objectContaining({ code: 'slotTaken' }) as Error);
    expect(() => parseHold({ status: 'paused' })).toThrow(expect.objectContaining({ code: 'paused' }) as Error);
  });

  it('reads the questions of an opaque template, by `kind` or `type`, and drops what it cannot show', () => {
    const questions = questionsOf({
      questions: [
        { key: 'a', type: 'yesNo', required: true, label: { en: 'A?' } },
        { key: 'b', kind: 'text', label: 'B?' },
        { key: 'c', kind: 'slider', label: { en: 'C?' } },
        { key: 'd', kind: 'choice', label: { en: 'D?' }, options: [{ value: 'x', label: { en: 'X' } }, { value: 1 }] },
      ],
    });
    expect(questions.map((q) => q.key)).toEqual(['a', 'b', 'd']);
    expect(questions[0]).toMatchObject({ kind: 'yesNo', required: true });
    expect(questions[1]?.label).toEqual({ en: 'B?' });
    expect(questions[2]?.options).toEqual([{ value: 'x', label: { en: 'X' } }]);
    expect(questionsOf([])).toEqual([]);
  });

  it('puts the professional profile beside the booking and derives the client first name', () => {
    const wire: WireBooking = {
      bookingId: 'b1',
      status: 'confirmed',
      phase: 'upcoming',
      slug: 'maria',
      professional: { displayName: 'Maria Beauty', businessName: 'Studio' },
      service: { id: 'a', name: 'Glow' },
      addOns: [],
      guestCount: 0,
      startsAt: '2026-10-02T13:00:00.000Z',
      endsAt: '2026-10-02T14:00:00.000Z',
      durationMinutes: 60,
      timeZoneID: 'America/Sao_Paulo',
      serverTime: '2026-10-01T00:00:00.000Z',
      client: { name: 'Helena Duarte' },
      policy: profile().policy,
      rulesText: { en: 'One' },
      actions: { cancel: 'free', reschedule: 'direct', isInsideFreeWindow: true, hoursUntilStart: 37, cancellationWouldBeLate: false, canConfirmPresence: true, canReportLate: false },
      rescheduleCount: 0,
      intakeRequired: true,
      tokenExpiresAt: '2026-10-09T14:00:00.000Z',
    };
    const page = parsePublicPage({ profile: profile(), intakeAvailable: true, features: { whatsAppAutomation: false, smsCallingCodes: [] }, serverTime: 'x' });
    const view = bookingView(wire, page);
    expect(view.client).toEqual({ name: 'Helena Duarte', firstName: 'Helena' });
    expect(view.professional.firstName).toBe('Maria');
    expect(view.professional.businessName).toBe('Studio');
    expect(view.rules['en']).toEqual([{ text: 'One' }]);
    expect(rulesFromText(undefined)).toEqual({});
  });
});

describe('client composition', () => {
  it('getBooking fetches her public page once per slug and getFormContext tolerates NOT_FOUND (no form published)', async () => {
    const calls: string[] = [];
    const api = createApi({
      call: (name, data) => {
        calls.push(name);
        switch (name) {
          case 'getPublicPage':
            return Promise.resolve({ profile: profile(), intakeAvailable: false, features: { whatsAppAutomation: false, smsCallingCodes: [] }, serverTime: 'x' });
          case 'getBooking':
            return Promise.resolve({
              bookingId: 'b1', status: 'confirmed', phase: 'past', slug: 'maria', professional: { displayName: 'Maria Beauty' }, service: { id: 'a', name: 'Glow' }, addOns: [], guestCount: 0,
              startsAt: '2026-10-02T13:00:00.000Z', endsAt: '2026-10-02T14:00:00.000Z', durationMinutes: 60, timeZoneID: 'UTC', serverTime: 'x', client: { name: 'Ana Lima' }, policy: profile().policy, rulesText: {},
              actions: { cancel: 'unavailable', reschedule: 'unavailable', isInsideFreeWindow: false, hoursUntilStart: -1, cancellationWouldBeLate: true, canConfirmPresence: false, canReportLate: false },
              rescheduleCount: 0, intakeRequired: true, tokenExpiresAt: 'x', ...(data as object),
            });
          case 'getFormContext':
            return Promise.reject(new ApiError('notFound', 404));
          default:
            return Promise.reject(new Error(name));
        }
      },
    });
    const context = await api.getFormContext('T');
    expect(context.intake.available).toBe(false);
    expect(context.inboxKey).toEqual(profile().inboxKey);
    expect(context.checkIn).toEqual({ available: true, serviceName: 'Glow' });
    expect(context.client.firstName).toBe('Ana');
    expect(calls.filter((name) => name === 'getPublicPage')).toHaveLength(1);
  });
});
