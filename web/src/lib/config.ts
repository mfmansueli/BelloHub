// Build-time configuration, read once. No origin, project id or key is hard-coded anywhere else in src/.

export type SmsVerifierMode = 'firebase' | 'api';
export type AppCheckMode = 'off' | 'debug' | 'recaptcha-enterprise';

export interface FirebaseWebConfig {
  readonly apiKey: string;
  readonly authDomain?: string;
  readonly projectId: string;
  readonly appId: string;
}

export interface AppConfig {
  readonly apiBase: string;
  readonly smsVerifier: SmsVerifierMode;
  readonly firebase: FirebaseWebConfig | null;
  readonly authEmulatorUrl: string | null;
  readonly appCheck: AppCheckMode;
  readonly appCheckSiteKey: string | null;
  readonly webBaseUrl: string | null;
}

function parseFirebaseConfig(raw: string | undefined): FirebaseWebConfig | null {
  if (raw === undefined || raw === '') return null;
  try {
    const value: unknown = JSON.parse(raw);
    if (typeof value === 'object' && value !== null) {
      const record = value as Record<string, unknown>;
      const { apiKey, projectId, appId, authDomain } = record;
      if (typeof apiKey === 'string' && typeof projectId === 'string' && typeof appId === 'string') {
        return { apiKey, projectId, appId, ...(typeof authDomain === 'string' ? { authDomain } : {}) };
      }
    }
  } catch {
    // an unreadable value is the same as none
  }
  return null;
}

export function readConfig(env: ImportMetaEnv): AppConfig {
  const appCheck = env.VITE_APP_CHECK;
  return {
    apiBase: (env.VITE_API_BASE_URL ?? '/api').replace(/\/+$/, ''),
    smsVerifier: env.VITE_SMS_VERIFIER === 'api' ? 'api' : 'firebase',
    firebase: parseFirebaseConfig(env.VITE_FIREBASE_CONFIG),
    authEmulatorUrl: env.VITE_AUTH_EMULATOR_URL ?? null,
    appCheck: appCheck === 'debug' || appCheck === 'recaptcha-enterprise' ? appCheck : 'off',
    appCheckSiteKey: env.VITE_APP_CHECK_SITE_KEY ?? null,
    webBaseUrl: env.VITE_WEB_BASE_URL ?? null,
  };
}

export const config: AppConfig = readConfig(import.meta.env);

/** The origin personal links are built on. */
export function linkBase(): string {
  return config.webBaseUrl ?? window.location.origin;
}
