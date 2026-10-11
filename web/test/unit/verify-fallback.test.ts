// "I didn't get the code" and trusted devices on the page (API.md 5.8): the stored token, the state machine's way back
// to the code, and the request the WhatsApp path sends.

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import type { PublicProfile } from '../../src/api/types';
import { allowedStep, emptyDraft, initialState, proofTarget, reduce, type BookingEvent, type BookingState } from '../../src/app/booking/machine';
import { forgetDeviceLocally, rememberDevice, storedDeviceToken, trustedDeviceFor } from '../../src/lib/trustedDevice';
import { buildCreateRequest } from '../../src/routes/booking/submit';

const TOKEN = 'AbCdEfGhIjKlMnOpQrStUv';
const NOW = Date.parse('2026-10-01T12:00:00Z');
const LATER = '2026-12-30T12:00:00.000Z';

function memoryStorage(): Storage {
  const data = new Map<string, string>();
  return {
    get length() {
      return data.size;
    },
    clear: () => {
      data.clear();
    },
    getItem: (key) => data.get(key) ?? null,
    key: (index) => [...data.keys()][index] ?? null,
    removeItem: (key) => {
      data.delete(key);
    },
    setItem: (key, value) => {
      data.set(key, value);
    },
  };
}

describe('trusted device storage', () => {
  beforeEach(() => {
    vi.stubGlobal('window', { localStorage: memoryStorage() });
  });
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('gives the token back only for the same page and the same address (any case), before it expires', () => {
    rememberDevice('maria', 'Helena@Example.com ', TOKEN, LATER);

    expect(trustedDeviceFor('maria', 'helena@example.com', NOW)).toBe(TOKEN);
    expect(trustedDeviceFor('maria', ' HELENA@example.com', NOW)).toBe(TOKEN);
    expect(trustedDeviceFor('maria', 'other@example.com', NOW)).toBeNull();
    expect(trustedDeviceFor('bruna', 'helena@example.com', NOW)).toBeNull();
    expect(trustedDeviceFor('maria', 'helena@example.com', Date.parse(LATER))).toBeNull();
  });

  it('stores the token under bh.device.<slug> with the address, and nothing else', () => {
    rememberDevice('maria', 'helena@example.com', TOKEN, LATER);

    const raw = window.localStorage.getItem('bh.device.maria');
    expect(JSON.parse(raw ?? '{}')).toEqual({ v: 1, email: 'helena@example.com', token: TOKEN, expiresAt: LATER });
    expect(window.localStorage.length).toBe(1);
  });

  it('ignores a malformed or tampered entry and a token of the wrong shape', () => {
    window.localStorage.setItem('bh.device.maria', '{"v":1,"email":"helena@example.com","token":"short","expiresAt":"x"}');
    expect(trustedDeviceFor('maria', 'helena@example.com', NOW)).toBeNull();
    window.localStorage.setItem('bh.device.maria', 'not json');
    expect(storedDeviceToken('maria')).toBeNull();

    rememberDevice('maria', 'helena@example.com', 'bad token', LATER);
    expect(storedDeviceToken('maria')).toBeNull();
  });

  it('forgets the token of one page', () => {
    rememberDevice('maria', 'helena@example.com', TOKEN, LATER);
    rememberDevice('bruna', 'helena@example.com', TOKEN, LATER);

    forgetDeviceLocally('maria');

    expect(storedDeviceToken('maria')).toBeNull();
    expect(storedDeviceToken('bruna')).toBe(TOKEN);
  });

  it('works without storage (an in-app browser that blocks it): nothing is kept and nothing throws', () => {
    const blocked = {
      get localStorage(): Storage {
        throw new DOMException('blocked', 'SecurityError');
      },
    };
    vi.stubGlobal('window', blocked);

    expect(() => {
      rememberDevice('maria', 'helena@example.com', TOKEN, LATER);
    }).not.toThrow();
    expect(trustedDeviceFor('maria', 'helena@example.com', NOW)).toBeNull();
    expect(() => {
      forgetDeviceLocally('maria');
    }).not.toThrow();
  });
});

describe('the booking machine with a trusted device', () => {
  const details: BookingEvent = { type: 'setDetails', name: 'Helena Duarte', phoneCountry: 'BR', phoneInput: '11 98765 4321', email: 'helena@example.com' };

  function atYou(): BookingState {
    return [
      { type: 'chooseService', serviceId: 'brazilian', addOnIds: [] },
      { type: 'chooseSlot', startsAt: '2026-10-02T13:00:00Z', holdExpiresAt: null },
      details,
    ].reduce<BookingState>((state, event) => reduce(state, event as BookingEvent), initialState(emptyDraft('maria', 'BR', 'key')));
  }

  it('a device proof skips the code step: the questions are open', () => {
    const state = reduce(atYou(), { type: 'verified', proof: { method: 'device', token: TOKEN }, target: proofTarget(atYou().draft) });

    expect(state.phase).toBe('questions');
    expect(allowedStep('questions', state)).toBe('questions');
  });

  it('when the server wants the code after all, the proof is dropped and the code step comes back', () => {
    const skipped = reduce(atYou(), { type: 'verified', proof: { method: 'device', token: TOKEN }, target: proofTarget(atYou().draft) });

    const back = reduce(skipped, { type: 'needsCode' });

    expect(back.phase).toBe('verify');
    expect(back.proof).toBeNull();
    expect(allowedStep('questions', back)).toBe('verify');
    expect(allowedStep('verify', back)).toBe('verify');
  });

  it('a corrected address on the code step keeps the step and changes the address', () => {
    const state = reduce(atYou(), { ...details, email: 'helena.duarte@example.com' });

    expect(state.draft.email).toBe('helena.duarte@example.com');
    expect(allowedStep('verify', state)).toBe('verify');
  });
});

describe('the request of "Confirm on WhatsApp"', () => {
  it('carries no proof and nothing beyond what was already collected', () => {
    const state = [
      { type: 'chooseService', serviceId: 'brazilian', addOnIds: [] },
      { type: 'chooseSlot', startsAt: '2026-10-02T13:00:00Z', holdExpiresAt: null },
      { type: 'setDetails', name: ' Helena Duarte ', phoneCountry: 'BR', phoneInput: '11 98765 4321', email: 'helena@example.com' },
    ].reduce<BookingState>((current, event) => reduce(current, event as BookingEvent), initialState(emptyDraft('maria', 'BR', 'key')));

    const request = buildCreateRequest({ slug: 'maria' } as PublicProfile, state, 'pt-BR', { note: '' }, { method: 'whatsapp' });

    expect(request).toMatchObject({
      slug: 'maria',
      verification: { method: 'whatsapp' },
      client: { name: 'Helena Duarte', phone: '+5511987654321', email: 'helena@example.com', locale: 'pt-BR' },
    });
    expect(request).not.toHaveProperty('note');
  });
});
