import type { Auth } from 'firebase-admin/auth';
import type { Firestore } from 'firebase-admin/firestore';

import type { PhoneVerifier } from '../auth/PhoneVerifier.js';
import type { AppStoreVerifier } from '../billing/AppStoreVerifier.js';
import type { BlobStore } from '../lib/blobs.js';
import type { Logger } from '../lib/log.js';
import type { Random } from '../lib/random.js';
import type { ClientMessenger } from '../messaging/ClientMessenger.js';
import type { PushSender } from '../push/PushSender.js';

/** Non-secret configuration, read once at start from params (`functions/.env.*`). */
export interface Settings {
  /** The public web origin, no trailing slash (O15: `https://bellohub.app`, H6). */
  webBaseUrl: string;
  /** D31: WhatsApp Cloud API on. Off by default; reminders are then prepared in the app. */
  whatsAppAutomation: boolean;
  /** Reject calls without a valid App Check token. Off until a human enables it after staging (H5). */
  enforceAppCheck: boolean;
  /** Emulator test hook: every email code is this value. Never set outside the emulator. */
  fixedEmailCode: string | undefined;
  /** Running in the Firebase emulator or a test. Enables the outbox and the fixed code, nothing else. */
  emulator: boolean;
  /** Validate every response against its schema (tests and the emulator). */
  validateOutputs: boolean;
  /** How many proxies in front of us append to X-Forwarded-For (Google's front end adds one). */
  trustedProxyHops: number;
  /** StoreKit product ids that unlock the plan (D33). */
  planProductIds: readonly string[];
}

/** Everything a use case touches, injected so tests can pin the clock and fake the outside world. */
export interface Deps {
  db: Firestore;
  auth: Auth;
  blobs: BlobStore;
  /** Epoch milliseconds. Never call Date.now() in a use case. */
  now: () => number;
  random: Random;
  /** HMAC key for phone, email and IP hashes (Secret Manager `PHONE_HASH_PEPPER`, H4). */
  pepper: string;
  settings: Settings;
  messenger: ClientMessenger;
  push: PushSender;
  phoneVerifier: PhoneVerifier;
  appStore: AppStoreVerifier;
  log: Logger;
}
