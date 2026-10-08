import { AppError } from '../lib/errors.js';
import type { AppStoreVerifier, VerifiedNotification, VerifiedTransaction } from './AppStoreVerifier.js';

/** TODO(HUMAN-H14): replace with AppleAppStoreVerifier once the root certificates and app ids are provided. */
export class UnconfiguredAppStoreVerifier implements AppStoreVerifier {
  readonly configured = false;

  verifyTransaction(_signedTransaction: string): Promise<VerifiedTransaction> {
    return Promise.reject(new AppError('NOT_CONFIGURED'));
  }

  verifyNotification(_signedPayload: string): Promise<VerifiedNotification> {
    return Promise.reject(new AppError('NOT_CONFIGURED'));
  }
}
