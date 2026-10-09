import type { AppleRevocationOutcome, AppleTokenRevoker } from './AppleTokenRevoker.js';

/** The default until a human sets the Sign in with Apple key (H17): every deletion reports `appleRevocation: "skipped"`. */
export class UnconfiguredAppleTokenRevoker implements AppleTokenRevoker {
  readonly configured = false;

  revoke(): Promise<AppleRevocationOutcome> {
    return Promise.resolve('skipped');
  }
}
