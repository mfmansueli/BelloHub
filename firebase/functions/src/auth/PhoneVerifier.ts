/**
 * Proof that the caller controls a phone number (docs/10 section 3). In production this is the Firebase Auth phone
 * provider (SMS, with the region allow-list of D37); the browser signs in with the code and passes the ID token.
 * Behind an interface so use cases never import an SDK and tests can inject a fixed hook.
 */
export interface PhoneVerifier {
  /** Resolves the verified E.164 number, or rejects with `VERIFICATION_FAILED`. */
  verify(idToken: string, now: number): Promise<{ phoneE164: string }>;
}
