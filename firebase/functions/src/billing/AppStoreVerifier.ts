/** A StoreKit 2 transaction whose Apple signature has been verified (D33: purchases are re-verified on the server). */
export interface VerifiedTransaction {
  productId: string;
  bundleId: string;
  /** The UUID the app passed at purchase; maps the transaction to an account. */
  appAccountToken?: string | undefined;
  /** End of the paid period, epoch milliseconds. */
  expiresAt?: number | undefined;
  revokedAt?: number | undefined;
  /** End of the billing grace period, when Apple is retrying the payment. */
  gracePeriodExpiresAt?: number | undefined;
  environment: 'Production' | 'Sandbox';
}

export interface VerifiedNotification {
  type: string;
  subtype?: string | undefined;
  transaction?: VerifiedTransaction | undefined;
}

/**
 * Apple's JWS verification behind an interface. The real adapter needs Apple's root certificates and the app's ids,
 * which a human supplies (H14); until then `UnconfiguredAppStoreVerifier` answers NOT_CONFIGURED and every plan stays
 * `none`, which is the safe side (no unlock without a verified purchase).
 */
export interface AppStoreVerifier {
  readonly configured: boolean;
  verifyTransaction(signedTransaction: string): Promise<VerifiedTransaction>;
  verifyNotification(signedPayload: string): Promise<VerifiedNotification>;
}
