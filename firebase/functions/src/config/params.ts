// Deploy-time parameters (functions/.env.<project> or the CLI prompt) and secrets (Secret Manager). Nothing secret is
// ever in the repository; the only secret the code needs today is the hashing pepper (H4). The email provider key and the
// WhatsApp token are declared together with their adapters when a human chooses the provider (H7, H13).

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
