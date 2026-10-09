import { AppError } from '../lib/errors.js';
import type { AppStoreVerifier, VerifiedNotification, VerifiedTransaction } from './AppStoreVerifier.js';

/** What `createDeps` wires until Apple's root certificates are in place (H14); then `AppleAppStoreVerifier` takes over. */
export class UnconfiguredAppStoreVerifier implements AppStoreVerifier {
  readonly configured = false;

  verifyTransaction(_signedTransaction: string): Promise<VerifiedTransaction> {
    return Promise.reject(new AppError('NOT_CONFIGURED'));
  }

  verifyNotification(_signedPayload: string): Promise<VerifiedNotification> {
    return Promise.reject(new AppError('NOT_CONFIGURED'));
  }
}
