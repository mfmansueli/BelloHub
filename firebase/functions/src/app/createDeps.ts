import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

import { FirebasePhoneVerifier } from '../auth/FirebasePhoneVerifier.js';
import { UnconfiguredAppStoreVerifier } from '../billing/UnconfiguredAppStoreVerifier.js';
import { ENFORCE_APP_CHECK, PHONE_HASH_PEPPER, PLAN_PRODUCT_IDS, WEB_BASE_URL, WHATSAPP_AUTOMATION } from '../config/params.js';
import { GcsBlobStore } from '../lib/blobs.js';
import { CloudLogSink } from '../lib/cloudLogSink.js';
import { createLogger } from '../lib/log.js';
import { systemRandom } from '../lib/random.js';
import { DisabledEmailProvider } from '../messaging/DisabledEmailProvider.js';
import { DisabledWhatsAppProvider } from '../messaging/DisabledWhatsAppProvider.js';
import { EmulatorEmailProvider } from '../messaging/EmulatorEmailProvider.js';
import { ProviderClientMessenger } from '../messaging/ProviderClientMessenger.js';
import { EmulatorPushSender } from '../push/EmulatorPushSender.js';
import { FcmPushSender } from '../push/FcmPushSender.js';
import type { Deps } from './Deps.js';

/** The emulator test hook for email codes: every code is this (docs/11, API.md section 5.5). Never used outside it. */
export const EMULATOR_EMAIL_CODE = '123456';

let cached: Deps | undefined;

/**
 * Wires the real world: Admin SDK, Cloud Logging, FCM, and in the emulator the recording stand-ins. Built once per
 * instance. HUMAN tasks live here as TODO markers: the email provider (H7), the App Store verifier (H14) and the
 * WhatsApp provider (H13) are the only places that will change when those accounts exist.
 */
export function createDeps(): Deps {
  if (cached) return cached;
  if (getApps().length === 0) initializeApp();
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
    },
    // TODO(HUMAN-H7): construct the chosen email provider here and pass `true` as the third argument.
    messenger: emulator
      ? new ProviderClientMessenger(new EmulatorEmailProvider(db), new DisabledWhatsAppProvider(), true)
      : new ProviderClientMessenger(new DisabledEmailProvider(), new DisabledWhatsAppProvider(), false),
    push: emulator ? new EmulatorPushSender(db) : new FcmPushSender(),
    phoneVerifier: new FirebasePhoneVerifier(getAuth()),
    // TODO(HUMAN-H14): AppleAppStoreVerifier with the Apple root certificates and the app ids.
    appStore: new UnconfiguredAppStoreVerifier(),
    log: createLogger(new CloudLogSink())
  };
  return cached;
}
