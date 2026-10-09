/// <reference types="vite/client" />

// Build-time configuration (docs/10 section 1, 11 section 1). Nothing here is a secret: the API base, the
// Firebase web config and the App Check site key are public by design. The real values come from the
// environment at build time (`firebase/config/<env>.json` supplies them in CI); none is hard-coded in src/.
interface ImportMetaEnv {
  /** Base URL of the public functions. Default `/api` (same origin, Hosting rewrites). */
  readonly VITE_API_BASE_URL?: string;
  /** `firebase` (Firebase Auth phone verification) or `api` (the server's own SMS endpoint, tests and dev). */
  readonly VITE_SMS_VERIFIER?: string;
  /** Firebase web app config as JSON: `{"apiKey":"...","authDomain":"...","projectId":"...","appId":"..."}`. */
  readonly VITE_FIREBASE_CONFIG?: string;
  /** Auth emulator URL, for local runs with `--project demo-bellohub`. */
  readonly VITE_AUTH_EMULATOR_URL?: string;
  /** `off`, `debug` (emulator) or `recaptcha-enterprise`. */
  readonly VITE_APP_CHECK?: string;
  readonly VITE_APP_CHECK_SITE_KEY?: string;
  /** Origin shown in personal links when it must differ from the page origin. */
  readonly VITE_WEB_BASE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
