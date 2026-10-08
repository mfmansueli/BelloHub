// The booking state of one professional's page, with the non-clinical draft kept in sessionStorage so a refresh does
// not lose it (docs/05 layer C, docs/10 section 3). A code, a proof, an answer to a first-visit question and the
// server's result stay in memory only.

import { createStore, useStore, type Store } from '../store';
import { STORAGE_KEYS, readSession, removeSession, writeSession } from '../../lib/storage';
import { reduce, initialState, emptyDraft, type BookingEvent, type BookingState, type Draft } from './machine';

const stores = new Map<string, Store<BookingState>>();

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

const str = (value: unknown, fallback = ''): string => (typeof value === 'string' ? value : fallback);
const nullableStr = (value: unknown): string | null => (typeof value === 'string' ? value : null);

/** Reads a stored draft defensively: anything unexpected is dropped, never trusted. */
export function parseDraft(text: string | null, slug: string, defaultCountry: string): Draft {
  const fresh = emptyDraft(slug, defaultCountry);
  if (text === null) return fresh;
  try {
    const parsed: unknown = JSON.parse(text);
    if (!isRecord(parsed) || parsed['v'] !== 1 || !isRecord(parsed['draft'])) return fresh;
    const stored = parsed['draft'];
    if (stored['slug'] !== slug) return fresh;
    const addOns = Array.isArray(stored['addOnIds']) ? stored['addOnIds'].filter((id): id is string => typeof id === 'string') : [];
    const guests = typeof stored['guests'] === 'number' && stored['guests'] >= 0 && stored['guests'] <= 2 ? stored['guests'] : 0;
    return {
      slug,
      serviceId: nullableStr(stored['serviceId']),
      addOnIds: addOns,
      guests,
      guestNames: Array.isArray(stored['guestNames']) ? stored['guestNames'].filter((n): n is string => typeof n === 'string').slice(0, guests) : [],
      startsAt: nullableStr(stored['startsAt']),
      holdId: nullableStr(stored['holdId']),
      holdExpiresAt: nullableStr(stored['holdExpiresAt']),
      name: str(stored['name']),
      phoneCountry: str(stored['phoneCountry'], defaultCountry),
      phoneInput: str(stored['phoneInput']),
      email: str(stored['email']),
      channel: stored['channel'] === 'email' ? 'email' : 'sms',
      idempotencyKey: str(stored['idempotencyKey'], fresh.idempotencyKey),
    };
  } catch {
    return fresh;
  }
}

export function serializeDraft(draft: Draft): string {
  return JSON.stringify({ v: 1, draft });
}

export function bookingStore(slug: string, defaultCountry: string): Store<BookingState> {
  let store = stores.get(slug);
  if (store === undefined) {
    const draft = parseDraft(readSession(STORAGE_KEYS.bookingDraft(slug)), slug, defaultCountry);
    const created = createStore<BookingState>(initialState(draft));
    created.subscribe(() => {
      const state = created.get();
      if (state.phase === 'confirmed' || state.phase === 'review') {
        // A finished attempt: the next visit starts clean and a refresh cannot rebook.
        removeSession(STORAGE_KEYS.bookingDraft(slug));
      } else {
        writeSession(STORAGE_KEYS.bookingDraft(slug), serializeDraft(state.draft));
      }
    });
    store = created;
    stores.set(slug, created);
  }
  return store;
}

export function dispatchBooking(slug: string, defaultCountry: string, event: BookingEvent): void {
  bookingStore(slug, defaultCountry).update((state) => reduce(state, event));
}

export function useBooking(slug: string, defaultCountry: string): readonly [BookingState, (event: BookingEvent) => void] {
  const store = bookingStore(slug, defaultCountry);
  const state = useStore(store);
  return [
    state,
    (event) => {
      store.update((current) => reduce(current, event));
    },
  ];
}
