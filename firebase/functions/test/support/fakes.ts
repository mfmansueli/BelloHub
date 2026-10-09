// Fakes for everything outside the process (docs/13: services get fakes, never the real thing). They record what they
// were asked so a test can assert on content, and some can be told to fail.

import type { AppleRevocationOutcome, AppleTokenRevoker } from '../../src/auth/AppleTokenRevoker.js';
import type { PhoneVerifier } from '../../src/auth/PhoneVerifier.js';
import type { AppStoreVerifier, VerifiedNotification, VerifiedTransaction } from '../../src/billing/AppStoreVerifier.js';
import { AppError } from '../../src/lib/errors.js';
import type { EmailMessage, EmailProvider } from '../../src/messaging/EmailProvider.js';
import type { WhatsAppProvider, WhatsAppTemplateMessage } from '../../src/messaging/WhatsAppProvider.js';
import type { PushMessage, PushResult, PushSender, PushTarget } from '../../src/push/PushSender.js';

export class FakeEmailProvider implements EmailProvider {
  readonly sent: EmailMessage[] = [];
  failNext = false;

  send(message: EmailMessage): Promise<void> {
    if (this.failNext) {
      this.failNext = false;
      return Promise.reject(new Error('provider down'));
    }
    this.sent.push(message);
    return Promise.resolve();
  }
}

export class FakeWhatsAppProvider implements WhatsAppProvider {
  enabled = true;
  readonly sent: WhatsAppTemplateMessage[] = [];

  sendTemplate(message: WhatsAppTemplateMessage): Promise<void> {
    this.sent.push(message);
    return Promise.resolve();
  }
}

export class FakePushSender implements PushSender {
  readonly calls: { targets: PushTarget[]; message: PushMessage }[] = [];
  /** Target ids to report as invalid on the next send. */
  invalidIds = new Set<string>();

  send(targets: PushTarget[], message: PushMessage): Promise<PushResult> {
    this.calls.push({ targets, message });
    return Promise.resolve({ invalidTargetIds: targets.filter((target) => this.invalidIds.has(target.id)).map((target) => target.id) });
  }

  messages(): PushMessage[] {
    return this.calls.map((call) => call.message);
  }
}

/** Stands in for Firebase Auth phone sign-in: `verified(phone)` returns an "ID token" the verifier accepts. */
export class FakePhoneVerifier implements PhoneVerifier {
  private readonly tokens = new Map<string, { phoneE164: string; authTime: number }>();
  private counter = 0;

  verified(phoneE164: string, authTime: number): string {
    this.counter += 1;
    const token = `fake-phone-id-token-${this.counter}-${phoneE164.slice(-4)}`;
    this.tokens.set(token, { phoneE164, authTime });
    return token;
  }

  verify(idToken: string, now: number): Promise<{ phoneE164: string }> {
    const known = this.tokens.get(idToken);
    if (!known || now - known.authTime > 10 * 60_000) return Promise.reject(new AppError('VERIFICATION_FAILED'));
    return Promise.resolve({ phoneE164: known.phoneE164 });
  }
}

/** Stands in for Apple's revocation endpoint: records the codes it saw and answers what it is told. */
export class FakeAppleTokenRevoker implements AppleTokenRevoker {
  configured = true;
  outcome: AppleRevocationOutcome = 'revoked';
  readonly codes: string[] = [];

  revoke(authorizationCode: string): Promise<AppleRevocationOutcome> {
    this.codes.push(authorizationCode);
    return Promise.resolve(this.outcome);
  }
}

export class FakeAppStoreVerifier implements AppStoreVerifier {
  configured = true;
  /** Thrown by the next verification instead of looking anything up (a retryable Apple failure, for example). */
  nextError: AppError | undefined;
  private readonly transactions = new Map<string, VerifiedTransaction>();
  private readonly notifications = new Map<string, VerifiedNotification>();

  addTransaction(signed: string, transaction: VerifiedTransaction): void {
    this.transactions.set(signed, transaction);
  }

  addNotification(signed: string, notification: VerifiedNotification): void {
    this.notifications.set(signed, notification);
  }

  verifyTransaction(signedTransaction: string): Promise<VerifiedTransaction> {
    if (this.nextError) return Promise.reject(this.takeError());
    const found = this.transactions.get(signedTransaction);
    return found ? Promise.resolve(found) : Promise.reject(new AppError('VERIFICATION_FAILED'));
  }

  verifyNotification(signedPayload: string): Promise<VerifiedNotification> {
    if (this.nextError) return Promise.reject(this.takeError());
    const found = this.notifications.get(signedPayload);
    return found ? Promise.resolve(found) : Promise.reject(new AppError('VERIFICATION_FAILED'));
  }

  private takeError(): AppError {
    const error = this.nextError ?? new AppError('VERIFICATION_FAILED');
    this.nextError = undefined;
    return error;
  }
}

/** A clock the test moves by hand. */
export class TestClock {
  constructor(public current: number) {}

  now = (): number => this.current;

  advance(ms: number): void {
    this.current += ms;
  }

  set(ms: number): void {
    this.current = ms;
  }
}
