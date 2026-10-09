// Deploy-time parameters (functions/.env.<project> or the CLI prompt) and secrets (Secret Manager). Nothing secret is
// ever in the repository: the hashing pepper (H4) and the email API key (H7) live in Secret Manager. The WhatsApp token
// is declared with its adapter when a human enables the provider (H13).

import { defineBoolean, defineInt, defineSecret, defineString } from 'firebase-functions/params';

/** Rejects calls without a valid App Check token. Off until staging passes and a human turns it on (H5). */
export const ENFORCE_APP_CHECK = defineBoolean('ENFORCE_APP_CHECK', { default: false });

/** The public web origin used in links inside emails (O15, H6). */
export const WEB_BASE_URL = defineString('WEB_BASE_URL', { default: 'https://bellohub.app' });

/** D31: WhatsApp Cloud API automation. Keep in step with the Remote Config flag the apps read. */
export const WHATSAPP_AUTOMATION = defineBoolean('WHATSAPP_AUTOMATION', { default: false });

/**
 * StoreKit product ids that unlock the plan (D33), comma separated. A string rather than a list parameter: the Firebase
 * CLI writes list defaults to .env files as `a,b` while the SDK parses them as JSON, which fails at run time.
 */
export const PLAN_PRODUCT_IDS = defineString('PLAN_PRODUCT_IDS', {
  default: 'com.bellohub.pro.monthly,com.bellohub.pro.yearly'
});

/**
 * How many proxies append to `X-Forwarded-For` before a request reaches a function; the client IP used by the rate
 * limits is counted from the END of that header (`lib/clientIp.ts`). Google's front end adds one entry. Behind Firebase
 * Hosting rewrites (`/api/<name>`) the Hosting layer adds another, so staging should set `2` once one function log
 * confirms the header shape: the Hosting EMULATOR's proxy adds none, so the right value cannot be proven locally
 * (docs/agent-notes/backend-web-integration.md). Too low only makes the limits key on the Hosting proxy's address;
 * too high lets a client dodge them with a forged entry, so the default stays 1 until a human checks.
 */
export const TRUSTED_PROXY_HOPS = defineInt('TRUSTED_PROXY_HOPS', { default: 1 });

/** HMAC key for phone, email and IP hashes. Rotating it detaches every stored contact, so treat it as permanent. */
export const PHONE_HASH_PEPPER = defineSecret('PHONE_HASH_PEPPER');

/**
 * Transactional email (H7): the vendor's API key in Secret Manager and the verified sender as a parameter. The provider is
 * built only when `EMAIL_FROM` is set (then the key is read); with it empty the secret is never read and email stays off.
 * The secret must exist for the deploy to go through: set a placeholder until the vendor account exists.
 */
export const EMAIL_API_KEY = defineSecret('EMAIL_API_KEY');
export const EMAIL_FROM = defineString('EMAIL_FROM', { default: '' });

/**
 * Sign in with Apple (D44, H17): `deleteAccount` revokes the professional's Apple grant with a client secret signed by the
 * team's Sign in with Apple key. The adapter is built only when `APPLE_SIGNIN_KEY_ID` is set (then the secret is read);
 * until then deletion reports `appleRevocation: "skipped"`. Like `EMAIL_API_KEY`, the secret must exist in Secret
 * Manager for a deploy to pass: a placeholder is fine while the key id is empty. The team id and the client id are fixed.
 */
export const APPLE_SIGNIN_TEAM_ID = 'X5392U638Q';
export const APPLE_SIGNIN_CLIENT_ID = 'com.bellohub';
export const APPLE_SIGNIN_KEY_ID = defineString('APPLE_SIGNIN_KEY_ID', { default: '' });
export const APPLE_SIGNIN_PRIVATE_KEY = defineSecret('APPLE_SIGNIN_PRIVATE_KEY');

/** Every function binds the same secrets, so any of them can hash, send email and talk to Apple. */
export const FUNCTION_SECRETS = [PHONE_HASH_PEPPER, EMAIL_API_KEY, APPLE_SIGNIN_PRIVATE_KEY];

/**
 * App Store verification (H14). The adapter is built only when `APPLE_ROOT_CERTS_DIR` holds at least one DER
 * certificate; until then every plan stays `none`. The bundle id is fixed (`com.bellohub`); Production also needs the
 * numeric app id from App Store Connect.
 */
export const APPLE_ROOT_CERTS_DIR = defineString('APPLE_ROOT_CERTS_DIR', { default: 'certs/apple' });
export const APPLE_ENVIRONMENT = defineString('APPLE_ENVIRONMENT', { default: 'Sandbox' });
export const APPLE_APP_ID = defineString('APPLE_APP_ID', { default: '' });
