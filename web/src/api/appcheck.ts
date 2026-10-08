// App Check (docs/06 section 7, docs/11 section 6): the public functions refuse requests without a token that
// proves they come from this page. The Firebase SDK is a lazy chunk, so it never counts against the initial
// bundle, and it is only loaded when the build configuration asks for App Check.
//
// TODO(HUMAN-H4): the real site key and the Firebase web config come from the Firebase project once it exists.
// Finding for the coordinator: reCAPTCHA Enterprise injects a Google-hosted script, which the page's own rule
// "no third-party scripts on any page that can contain a form" (docs/06 section 6) forbids. See docs/agent-notes/web.md.

import type { AppConfig } from '../lib/config';

type TokenSource = () => Promise<string | null>;

let source: Promise<TokenSource> | null = null;

async function initialise(config: AppConfig): Promise<TokenSource> {
  const firebase = config.firebase;
  if (firebase === null) return () => Promise.resolve(null);
  const [{ initializeApp, getApps }, appCheck] = await Promise.all([import('@firebase/app'), import('@firebase/app-check')]);
  const app = getApps()[0] ?? initializeApp(firebase);
  if (config.appCheck === 'debug') {
    // Emulator and local runs: the SDK prints a debug token to register once in the console.
    (self as unknown as { FIREBASE_APPCHECK_DEBUG_TOKEN?: boolean }).FIREBASE_APPCHECK_DEBUG_TOKEN = true;
  }
  const instance = appCheck.initializeAppCheck(app, {
    provider: new appCheck.ReCaptchaEnterpriseProvider(config.appCheckSiteKey ?? 'debug-site-key'),
    isTokenAutoRefreshEnabled: true,
  });
  return async () => (await appCheck.getToken(instance)).token;
}

/** A token for the `X-Firebase-AppCheck` header, or null when App Check is off or unavailable (never throws). */
export async function getAppCheckToken(config: AppConfig): Promise<string | null> {
  if (config.appCheck === 'off') return null;
  source ??= initialise(config).catch((): TokenSource => () => Promise.resolve(null));
  try {
    return await (await source)();
  } catch {
    return null;
  }
}
