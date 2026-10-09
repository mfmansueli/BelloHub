// Deploy-time parameters (functions/.env.<project> or the CLI prompt) and secrets (Secret Manager). Nothing secret is
// ever in the repository: the hashing pepper (H4) and the email API key (H7) live in Secret Manager. The WhatsApp token
// is declared with its adapter when a human enables the provider (H13).

import { defineBoolean, defineSecret, defineString } from 'firebase-functions/params';

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

/** HMAC key for phone, email and IP hashes. Rotating it detaches every stored contact, so treat it as permanent. */
export const PHONE_HASH_PEPPER = defineSecret('PHONE_HASH_PEPPER');

/**
 * Transactional email (H7): the vendor's API key in Secret Manager and the verified sender as a parameter. The provider is
 * built only when `EMAIL_FROM` is set (then the key is read); with it empty the secret is never read and email stays off.
 * The secret must exist for the deploy to go through: set a placeholder until the vendor account exists.
 */
export const EMAIL_API_KEY = defineSecret('EMAIL_API_KEY');
export const EMAIL_FROM = defineString('EMAIL_FROM', { default: '' });

/** Every function binds the same secrets, so any of them can hash and send email. */
export const FUNCTION_SECRETS = [PHONE_HASH_PEPPER, EMAIL_API_KEY];

/**
 * App Store verification (H14). The adapter is built only when `APPLE_ROOT_CERTS_DIR` holds at least one DER
 * certificate; until then every plan stays `none`. The bundle id is fixed (`com.bellohub`); Production also needs the
 * numeric app id from App Store Connect.
 */
export const APPLE_ROOT_CERTS_DIR = defineString('APPLE_ROOT_CERTS_DIR', { default: 'certs/apple' });
export const APPLE_ENVIRONMENT = defineString('APPLE_ENVIRONMENT', { default: 'Sandbox' });
export const APPLE_APP_ID = defineString('APPLE_APP_ID', { default: '' });
