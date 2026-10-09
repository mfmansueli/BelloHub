import { getAuth } from 'firebase-admin/auth';

import type { Deps } from '../../src/app/Deps.js';
import type { AnyUseCase } from '../../src/app/UseCase.js';
import { invokeUseCase } from '../../src/http/invoke.js';
import { GcsBlobStore } from '../../src/lib/blobs.js';
import { createLogger, MemoryLogSink } from '../../src/lib/log.js';
import { systemRandom } from '../../src/lib/random.js';
import { keyedHash } from '../../src/lib/crypto.js';
import { ProviderClientMessenger } from '../../src/messaging/ProviderClientMessenger.js';
import { adminApp, clearAuth, clearFirestore, STORAGE_BUCKET, testFirestore } from './emulator.js';
import {
  FakeAppStoreVerifier,
  FakeEmailProvider,
  FakePhoneVerifier,
  FakePushSender,
  FakeWhatsAppProvider,
  TestClock
} from './fakes.js';

/** Thursday 2026-10-01, 12:00 in Sao Paulo (15:00 UTC): the same "today" as the iOS tests (`TestClock.now`). */
export const NOW = Date.UTC(2026, 9, 1, 15, 0);
export const PEPPER = 'test-pepper-not-a-secret';

export interface TestEnv {
  deps: Deps;
  clock: TestClock;
  mail: FakeEmailProvider;
  whatsapp: FakeWhatsAppProvider;
  push: FakePushSender;
  phone: FakePhoneVerifier;
  appStore: FakeAppStoreVerifier;
  logs: MemoryLogSink;
  /** Runs a use case through the same gate the deployed function uses (access, strict input, output schema). */
  call(useCase: AnyUseCase, data: unknown, who?: { uid?: string; authPhone?: string; ip?: string; appCheck?: boolean }): Promise<unknown>;
  /** An "ID token" for a phone that just signed in by SMS. */
  phoneToken(phoneE164: string): string;
}

export function createTestEnv(overrides: { whatsAppAutomation?: boolean; enforceAppCheck?: boolean } = {}): TestEnv {
  const clock = new TestClock(NOW);
  const mail = new FakeEmailProvider();
  const whatsapp = new FakeWhatsAppProvider();
  const push = new FakePushSender();
  const phone = new FakePhoneVerifier();
  const appStore = new FakeAppStoreVerifier();
  const logs = new MemoryLogSink();
  whatsapp.enabled = overrides.whatsAppAutomation ?? false;

  const deps: Deps = {
    db: testFirestore(),
    auth: getAuth(adminApp()),
    blobs: new GcsBlobStore(STORAGE_BUCKET, adminApp()),
    now: clock.now,
    random: systemRandom,
    pepper: PEPPER,
    settings: {
      webBaseUrl: 'https://bellohub.test',
      whatsAppAutomation: overrides.whatsAppAutomation ?? false,
      enforceAppCheck: overrides.enforceAppCheck ?? false,
      fixedEmailCode: undefined,
      emulator: true,
      validateOutputs: true,
      trustedProxyHops: 1,
      planProductIds: ['com.bellohub.pro.monthly', 'com.bellohub.pro.yearly']
    },
    messenger: new ProviderClientMessenger(mail, whatsapp, true),
    push,
    phoneVerifier: phone,
    appStore,
    log: createLogger(logs)
  };

  return {
    deps,
    clock,
    mail,
    whatsapp,
    push,
    phone,
    appStore,
    logs,
    call: (useCase, data, who = {}) =>
      invokeUseCase(deps, useCase, {
        data,
        uid: who.uid,
        authPhone: who.authPhone,
        appCheck: who.appCheck ?? true,
        ipHash: keyedHash(PEPPER, 'ip', who.ip ?? '203.0.113.7')
      }),
    phoneToken: (phoneE164) => phone.verified(phoneE164, clock.now())
  };
}

/** Wipes the emulators; call in `beforeEach`. Storage has no "clear" endpoint, so it is emptied object by object on request. */
export async function resetEmulators(env: TestEnv, options: { storage?: boolean; auth?: boolean } = {}): Promise<void> {
  await clearFirestore();
  if (options.auth) await clearAuth();
  if (!options.storage) return;
  let page: string | undefined;
  do {
    const listed = await env.deps.blobs.list('', page);
    for (const path of listed.paths) await env.deps.blobs.delete(path);
    page = listed.next;
  } while (page);
}

/** The Storage objects of one sealed item (its name carries the ciphertext hash, so a test looks it up by prefix). */
export async function envelopeBlobs(env: TestEnv, uid: string, itemId: string): Promise<string[]> {
  return (await env.deps.blobs.list(`inbox/${uid}/${itemId}.`)).paths;
}
