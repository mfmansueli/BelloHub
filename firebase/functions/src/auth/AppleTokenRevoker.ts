/**
 * What `deleteAccount` reports about the Sign in with Apple token (D44): `revoked` when Apple confirmed, `failed` when
 * the adapter is configured but Apple refused or was unreachable, `skipped` when no adapter is configured or the app
 * sent no authorization code. A failure never blocks the deletion of her data.
 */
export type AppleRevocationOutcome = 'revoked' | 'failed' | 'skipped';

/**
 * Revokes the Sign in with Apple grant of a professional who deletes her account (D44, App Store Review Guideline
 * 5.1.1(v)). The app obtains a fresh authorization code just before calling `deleteAccount`; the adapter exchanges it
 * for Apple's tokens and revokes them. Behind an interface so use cases never import an SDK or call the network.
 */
export interface AppleTokenRevoker {
  /** True when the credentials (team, client id, key) are configured in this environment. */
  readonly configured: boolean;
  /** Never throws: an outcome is returned whatever Apple answers. */
  revoke(authorizationCode: string): Promise<AppleRevocationOutcome>;
}
