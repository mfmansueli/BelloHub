import { getApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

import { FirebasePhoneVerifier } from '../auth/FirebasePhoneVerifier.js';
import { AppleAppStoreVerifier } from '../billing/AppleAppStoreVerifier.js';
import type { AppStoreVerifier } from '../billing/AppStoreVerifier.js';
import { loadAppleRootCertificates } from '../billing/appleRootCertificates.js';
import { UnconfiguredAppStoreVerifier } from '../billing/UnconfiguredAppStoreVerifier.js';
import {
  APPLE_APP_ID,
  APPLE_ENVIRONMENT,
  APPLE_ROOT_CERTS_DIR,
  EMAIL_API_KEY,
  EMAIL_FROM,
  ENFORCE_APP_CHECK,
  PHONE_HASH_PEPPER,
  PLAN_PRODUCT_IDS,
  WEB_BASE_URL,
  WHATSAPP_AUTOMATION
} from '../config/params.js';
import { GcsBlobStore } from '../lib/blobs.js';
import { CloudLogSink } from '../lib/cloudLogSink.js';
import { createLogger } from '../lib/log.js';
import { systemRandom } from '../lib/random.js';
import { DisabledEmailProvider } from '../messaging/DisabledEmailProvider.js';
import { DisabledWhatsAppProvider } from '../messaging/DisabledWhatsAppProvider.js';
import { EmulatorEmailProvider } from '../messaging/EmulatorEmailProvider.js';
import { ProviderClientMessenger } from '../messaging/ProviderClientMessenger.js';
import { ResendEmailProvider } from '../messaging/ResendEmailProvider.js';
import { EmulatorPushSender } from '../push/EmulatorPushSender.js';
import { FcmPushSender } from '../push/FcmPushSender.js';
import type { Deps } from './Deps.js';

/** The emulator test hook for email codes: every code is this (docs/11, API.md section 5.5). Never used outside it. */
export const EMULATOR_EMAIL_CODE = '123456';

let cached: Deps | undefined;

/**
 * Wires the real world: Admin SDK, Cloud Logging, FCM, and in the emulator the recording stand-ins. Built once per
 * instance. The email provider (H7) and the App Store verifier (H14) switch themselves on from their parameters; the
 * WhatsApp provider (H13) is the one TODO left.
 */
export function createDeps(): Deps {
  if (cached) return cached;
  try {
    getApp();
  } catch {
    // Not initialized yet. (Other apps may exist, so the presence of any app is not the test.)
    initializeApp();
  }
  const db = getFirestore();
  try {
    // Optional fields are simply omitted from writes. Must run before the first use of `db`.
    db.settings({ ignoreUndefinedProperties: true });
  } catch {
    // Already configured by an earlier call in this process.
  }
  const emulator = process.env.FUNCTIONS_EMULATOR === 'true';

  cached = {
    db,
    auth: getAuth(),
    blobs: new GcsBlobStore(),
    now: () => Date.now(),
    random: systemRandom,
    pepper: PHONE_HASH_PEPPER.value(),
    settings: {
      webBaseUrl: WEB_BASE_URL.value().replace(/\/+$/, ''),
      whatsAppAutomation: WHATSAPP_AUTOMATION.value(),
      enforceAppCheck: ENFORCE_APP_CHECK.value(),
      fixedEmailCode: emulator ? EMULATOR_EMAIL_CODE : undefined,
      emulator,
      validateOutputs: emulator,
      trustedProxyHops: 1,
      planProductIds: PLAN_PRODUCT_IDS.value()
        .split(',')
        .map((id) => id.trim())
        .filter((id) => id.length > 0)
    },
    messenger: emulator ? new ProviderClientMessenger(new EmulatorEmailProvider(db), new DisabledWhatsAppProvider(), true) : createMessenger(),
    push: emulator ? new EmulatorPushSender(db) : new FcmPushSender(),
    phoneVerifier: new FirebasePhoneVerifier(getAuth()),
    appStore: createAppStoreVerifier(),
    log: createLogger(new CloudLogSink())
  };
  return cached;
}

/** TODO(HUMAN-H14): put Apple's root certificates in `certs/apple/` and set `APPLE_ENVIRONMENT` + `APPLE_APP_ID` for Production. */
function createAppStoreVerifier(): AppStoreVerifier {
  const rootCertificates = loadAppleRootCertificates(APPLE_ROOT_CERTS_DIR.value());
  if (rootCertificates.length === 0) return new UnconfiguredAppStoreVerifier();
  const appAppleId = Number.parseInt(APPLE_APP_ID.value(), 10);
  return AppleAppStoreVerifier.create({
    bundleId: 'com.bellohub',
    environment: APPLE_ENVIRONMENT.value() === 'Production' ? 'Production' : 'Sandbox',
    appAppleId: Number.isFinite(appAppleId) ? appAppleId : undefined,
    rootCertificates
  });
}

/** TODO(HUMAN-H7): set `EMAIL_FROM` and the `EMAIL_API_KEY` secret once the vendor account (Resend, EU region) has a DPA. */
function createMessenger(): ProviderClientMessenger {
  const from = EMAIL_FROM.value();
  const email = from ? ResendEmailProvider.ifConfigured({ apiKey: EMAIL_API_KEY.value(), from }) : undefined;
  return new ProviderClientMessenger(email ?? new DisabledEmailProvider(), new DisabledWhatsAppProvider(), email !== undefined);
}
