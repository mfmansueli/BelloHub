// Firebase Auth phone verification (D31): an SMS code, confirmed in the browser, turned into an ID token that
// `createBooking` and `findBookings` verify on the server. Loaded lazily, only on the verify and find pages.
//
// Auth state is kept in memory only (never IndexedDB or a cookie): the client has no account, the token is
// used once and the page forgets it. TODO(HUMAN-H4): needs the Firebase web config; untested against a real
// project (the Auth emulator is the local check).

import type { FirebaseWebConfig } from '../lib/config';

export interface PhoneSession {
  readonly confirm: (code: string) => Promise<string>;
}

export async function startPhoneVerification(
  firebase: FirebaseWebConfig,
  emulatorUrl: string | null,
  phoneE164: string,
  container: HTMLElement,
  languageCode: string,
): Promise<PhoneSession> {
  const [{ initializeApp, getApps }, auth] = await Promise.all([import('@firebase/app'), import('@firebase/auth')]);
  const app = getApps()[0] ?? initializeApp(firebase);
  const instance = auth.initializeAuth(app, { persistence: auth.inMemoryPersistence });
  if (emulatorUrl !== null) auth.connectAuthEmulator(instance, emulatorUrl, { disableWarnings: true });
  instance.languageCode = languageCode;
  const verifier = new auth.RecaptchaVerifier(instance, container, { size: 'invisible' });
  const confirmation = await auth.signInWithPhoneNumber(instance, phoneE164, verifier);
  return {
    confirm: async (code) => {
      const credential = await confirmation.confirm(code);
      const idToken = await credential.user.getIdToken();
      await auth.signOut(instance);
      return idToken;
    },
  };
}
