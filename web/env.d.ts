/// <reference types="vite/client" />

// Build-time configuration (docs/10 section 1, 11 section 1). Nothing here is a secret. D46: no Firebase web config
// and no App Check key, because the page ships no Firebase SDK.
interface ImportMetaEnv {
  /** Base URL of the public functions. Default `/api` (same origin, Hosting rewrites). */
  readonly VITE_API_BASE_URL?: string;
  /** Origin shown in personal links when it must differ from the page origin. */
  readonly VITE_WEB_BASE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
