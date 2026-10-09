// Browser storage is optional: WhatsApp's and Instagram's in-app browsers, private windows and blocked site data
// can make it throw or come back empty. Every read and write is guarded, and the page works without it.
//
// What may be stored (docs/05-DATA-MODEL.md layer C, docs/06 section 3.5):
//   localStorage    the chosen page language, nothing else
//   sessionStorage  non-clinical booking fields (service, time, name, phone) so a refresh does not lose them
// A health answer, a code or a token is never stored. The routes that handle them import nothing from here.

export const STORAGE_KEYS = {
  language: 'bh.lang',
  bookingDraft: (slug: string): string => `bh.draft.${slug}`,
} as const;

function safe<T>(action: () => T, fallback: T): T {
  try {
    return action();
  } catch {
    return fallback;
  }
}

export function readLocal(key: string): string | null {
  return safe(() => window.localStorage.getItem(key), null);
}

export function writeLocal(key: string, value: string): void {
  safe(() => {
    window.localStorage.setItem(key, value);
  }, undefined);
}

export function readSession(key: string): string | null {
  return safe(() => window.sessionStorage.getItem(key), null);
}

export function writeSession(key: string, value: string): void {
  safe(() => {
    window.sessionStorage.setItem(key, value);
  }, undefined);
}

export function removeSession(key: string): void {
  safe(() => {
    window.sessionStorage.removeItem(key);
  }, undefined);
}
