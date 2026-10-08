// Phone and email verification behind one small interface (D31, D37): the page asks a Verifier to send a code
// and to confirm it, and gets back a proof the server checks. Which implementation runs is build configuration.

import type { Api } from './client';
import { ApiError } from './errors';
import { startPhoneVerification, type PhoneSession } from './firebasePhone';
import type { SendCodeResponse, VerificationProof } from './types';
import type { AppConfig } from '../lib/config';
import type { LocaleId } from '../lib/locales';

export type VerifyTarget =
  | { readonly kind: 'sms'; readonly phone: string }
  | { readonly kind: 'email'; readonly email: string };

export interface Verifier {
  readonly target: VerifyTarget;
  start(): Promise<SendCodeResponse>;
  confirm(code: string): Promise<VerificationProof>;
}

export interface VerifierContext {
  readonly api: Api;
  readonly config: AppConfig;
  readonly slug: string;
  readonly locale: LocaleId;
  readonly purpose: 'booking' | 'find';
  /** An empty element in the page where the invisible reCAPTCHA of Firebase Auth may render. */
  readonly captchaContainer?: HTMLElement | null;
}

class EmailVerifier implements Verifier {
  constructor(
    readonly target: Extract<VerifyTarget, { kind: 'email' }>,
    private readonly context: VerifierContext,
  ) {}

  start(): Promise<SendCodeResponse> {
    return this.context.api.sendEmailCode({
      slug: this.context.slug,
      email: this.target.email,
      locale: this.context.locale,
      purpose: this.context.purpose,
    });
  }

  async confirm(code: string): Promise<VerificationProof> {
    return { kind: 'email', token: await this.context.api.verifyEmailCode(this.target.email, code) };
  }
}

/** The server sends the SMS itself: tests and local development. */
class ApiSmsVerifier implements Verifier {
  constructor(
    readonly target: Extract<VerifyTarget, { kind: 'sms' }>,
    private readonly context: VerifierContext,
  ) {}

  start(): Promise<SendCodeResponse> {
    return this.context.api.sendSmsCode(this.target.phone, this.context.slug);
  }

  async confirm(code: string): Promise<VerificationProof> {
    return { kind: 'sms', idToken: await this.context.api.verifySmsCode(this.target.phone, code) };
  }
}

/** Firebase Auth phone verification (production). */
class FirebaseSmsVerifier implements Verifier {
  private session: PhoneSession | null = null;

  constructor(
    readonly target: Extract<VerifyTarget, { kind: 'sms' }>,
    private readonly context: VerifierContext,
  ) {}

  async start(): Promise<SendCodeResponse> {
    const { config, captchaContainer, locale } = this.context;
    if (config.firebase === null || captchaContainer === undefined || captchaContainer === null) {
      throw new ApiError('unavailable');
    }
    try {
      this.session = await startPhoneVerification(
        config.firebase,
        config.authEmulatorUrl,
        this.target.phone,
        captchaContainer,
        locale,
      );
    } catch {
      throw new ApiError('unavailable');
    }
    return { resendAfterSeconds: 30 };
  }

  async confirm(code: string): Promise<VerificationProof> {
    if (this.session === null) throw new ApiError('codeExpired');
    try {
      return { kind: 'sms', idToken: await this.session.confirm(code) };
    } catch {
      throw new ApiError('codeInvalid');
    }
  }
}

export function createVerifier(target: VerifyTarget, context: VerifierContext): Verifier {
  if (target.kind === 'email') return new EmailVerifier(target, context);
  return context.config.smsVerifier === 'api' ? new ApiSmsVerifier(target, context) : new FirebaseSmsVerifier(target, context);
}
