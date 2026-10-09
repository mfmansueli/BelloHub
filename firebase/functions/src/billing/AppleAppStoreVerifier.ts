import { Environment, SignedDataVerifier, VerificationException, VerificationStatus } from '@apple/app-store-server-library';
import type { JWSRenewalInfoDecodedPayload, JWSTransactionDecodedPayload, ResponseBodyV2DecodedPayload } from '@apple/app-store-server-library';

import { AppError } from '../lib/errors.js';
import type { AppStoreVerifier, VerifiedNotification, VerifiedTransaction } from './AppStoreVerifier.js';

export type AppleEnvironment = 'Production' | 'Sandbox';

export interface AppleVerifierConfig {
  /** `com.bellohub` (the app target's bundle identifier). */
  bundleId: string;
  environment: AppleEnvironment;
  /** The numeric app id from App Store Connect; Apple requires it in Production and ignores it in Sandbox. */
  appAppleId?: number | undefined;
  /** Apple's root certificates, DER encoded (H14). */
  rootCertificates: readonly Buffer[];
  /** OCSP revocation checks against Apple (network). On in production; off in tests. */
  onlineChecks?: boolean | undefined;
}

/** The three calls of Apple's `SignedDataVerifier` that the adapter uses, so a test can stand in for the library. */
export interface SignedDataVerifierLike {
  verifyAndDecodeTransaction(signedTransactionInfo: string): Promise<JWSTransactionDecodedPayload>;
  verifyAndDecodeRenewalInfo(signedRenewalInfo: string): Promise<JWSRenewalInfoDecodedPayload>;
  verifyAndDecodeNotification(signedPayload: string): Promise<ResponseBodyV2DecodedPayload>;
}

/**
 * Apple's JWS verification through `@apple/app-store-server-library` (H14). The library checks the certificate chain
 * against the root certificates, the bundle id, the environment and, in Production, the app id; this class maps the
 * decoded payloads onto the plan model and every failure onto `VERIFICATION_FAILED`, with the one exception of a
 * failure Apple calls retryable (a network problem during the online check), which is `TRY_AGAIN` so the webhook
 * answers 503 and Apple sends the notification again.
 */
export class AppleAppStoreVerifier implements AppStoreVerifier {
  readonly configured = true;

  constructor(
    private readonly config: Pick<AppleVerifierConfig, 'bundleId' | 'environment'>,
    private readonly verifier: SignedDataVerifierLike
  ) {}

  /** The real thing. Throws when `rootCertificates` is empty or Production comes without an app id. */
  static create(config: AppleVerifierConfig): AppleAppStoreVerifier {
    if (config.rootCertificates.length === 0) throw new Error('AppleAppStoreVerifier needs at least one root certificate');
    const verifier = new SignedDataVerifier(
      [...config.rootCertificates],
      config.onlineChecks ?? true,
      config.environment === 'Production' ? Environment.PRODUCTION : Environment.SANDBOX,
      config.bundleId,
      config.appAppleId
    );
    return new AppleAppStoreVerifier(config, verifier);
  }

  async verifyTransaction(signedTransaction: string): Promise<VerifiedTransaction> {
    const decoded = await this.guard(() => this.verifier.verifyAndDecodeTransaction(signedTransaction));
    return this.transactionOf(decoded, undefined);
  }

  async verifyNotification(signedPayload: string): Promise<VerifiedNotification> {
    const decoded = await this.guard(() => this.verifier.verifyAndDecodeNotification(signedPayload));
    const type = typeof decoded.notificationType === 'string' ? decoded.notificationType : 'UNKNOWN';
    const subtype = typeof decoded.subtype === 'string' ? decoded.subtype : undefined;
    const signedTransactionInfo = decoded.data?.signedTransactionInfo;
    if (!signedTransactionInfo) return { type, subtype };

    const transaction = await this.guard(() => this.verifier.verifyAndDecodeTransaction(signedTransactionInfo));
    const renewal = decoded.data?.signedRenewalInfo
      ? await this.guard(() => this.verifier.verifyAndDecodeRenewalInfo(decoded.data?.signedRenewalInfo ?? ''))
      : undefined;
    return { type, subtype, transaction: this.transactionOf(transaction, renewal) };
  }

  // MARK: - Mapping

  /** The decoded payload as the plan model sees it. The library already checked bundle id and environment; checked again here because a wrong answer unlocks a plan. */
  private transactionOf(decoded: JWSTransactionDecodedPayload, renewal: JWSRenewalInfoDecodedPayload | undefined): VerifiedTransaction {
    if (decoded.bundleId !== this.config.bundleId || decoded.environment !== this.config.environment || !decoded.productId) {
      throw new AppError('VERIFICATION_FAILED');
    }
    return {
      productId: decoded.productId,
      bundleId: decoded.bundleId,
      appAccountToken: decoded.appAccountToken,
      expiresAt: decoded.expiresDate,
      revokedAt: decoded.revocationDate,
      gracePeriodExpiresAt: renewal?.gracePeriodExpiresDate,
      environment: this.config.environment
    };
  }

  private async guard<T>(call: () => Promise<T>): Promise<T> {
    try {
      return await call();
    } catch (error) {
      if (error instanceof VerificationException && error.status === VerificationStatus.RETRYABLE_VERIFICATION_FAILURE) {
        throw new AppError('TRY_AGAIN');
      }
      throw new AppError('VERIFICATION_FAILED');
    }
  }
}
