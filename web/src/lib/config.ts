// Build-time configuration, read once. No origin, project id or key is hard-coded anywhere else in src/.
// D46: the page ships no Firebase SDK and no App Check provider, so there is no Firebase configuration here.

export interface AppConfig {
  readonly apiBase: string;
  readonly webBaseUrl: string | null;
}

export function readConfig(env: ImportMetaEnv): AppConfig {
  return {
    apiBase: (env.VITE_API_BASE_URL ?? '/api').replace(/\/+$/, ''),
    webBaseUrl: env.VITE_WEB_BASE_URL ?? null,
  };
}

export const config: AppConfig = readConfig(import.meta.env);

/** The origin personal links are built on. */
export function linkBase(): string {
  return config.webBaseUrl ?? window.location.origin;
}

/**
 * The public booking page of a professional. D50: this, never a manage or portal link, is the only address that goes
 * into the calendar file and the Google Calendar link, because a token in a URL leaks through calendar sharing,
 * history and referrers.
 */
export function pageUrl(slug: string): string {
  return `${linkBase()}/${slug}`;
}
