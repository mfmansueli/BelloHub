// "Returning clients skip the code" (API.md 5.8, `device`): after a booking confirmed with an e-mail code the server
// hands this browser a token for that page and that address. It sits in localStorage under `bh.device.<slug>`, guarded
// like every storage call: an in-app browser that blocks storage simply asks for a code every time.
//
// The token is the only secret the page keeps. It proves nothing but "this browser verified this address on this page
// before"; it never opens a booking. "Forget this device" on the management page removes it here and on the server.

import { readLocal, removeLocal, STORAGE_KEYS, writeLocal } from './storage';

interface Stored {
  readonly v: 1;
  readonly email: string;
  readonly token: string;
  readonly expiresAt: string;
}

const TOKEN = /^[A-Za-z0-9_-]{22}$/;

function parse(text: string | null): Stored | null {
  if (text === null) return null;
  try {
    const value: unknown = JSON.parse(text);
    if (typeof value !== 'object' || value === null) return null;
    const stored = value as Partial<Stored>;
    if (stored.v !== 1 || typeof stored.email !== 'string' || typeof stored.token !== 'string' || typeof stored.expiresAt !== 'string') return null;
    if (!TOKEN.test(stored.token) || Number.isNaN(Date.parse(stored.expiresAt))) return null;
    return stored as Stored;
  } catch {
    return null;
  }
}

const normalize = (email: string): string => email.trim().toLowerCase();

/** The token for this page when it was issued for this same address and is still valid; null otherwise. */
export function trustedDeviceFor(slug: string, email: string, now: number = Date.now()): string | null {
  const stored = parse(readLocal(STORAGE_KEYS.trustedDevice(slug)));
  if (stored === null || Date.parse(stored.expiresAt) <= now) return null;
  return stored.email === normalize(email) ? stored.token : null;
}

/** Any token kept for this page (the management page offers to forget it). */
export function storedDeviceToken(slug: string): string | null {
  return parse(readLocal(STORAGE_KEYS.trustedDevice(slug)))?.token ?? null;
}

export function rememberDevice(slug: string, email: string, token: string, expiresAt: string): void {
  if (!TOKEN.test(token)) return;
  const value: Stored = { v: 1, email: normalize(email), token, expiresAt };
  writeLocal(STORAGE_KEYS.trustedDevice(slug), JSON.stringify(value));
}

export function forgetDeviceLocally(slug: string): void {
  removeLocal(STORAGE_KEYS.trustedDevice(slug));
}
