import type { Auth } from 'firebase-admin/auth';

import { PHONE_AUTH_MAX_AGE_SECONDS } from '../config/limits.js';
import { AppError } from '../lib/errors.js';
import type { PhoneVerifier } from './PhoneVerifier.js';

/**
 * Accepts a Firebase ID token only when the sign-in was by SMS (`phone` provider), carries a phone number, and was done
 * in the last ten minutes. In the Auth emulator the same code path runs: the emulator mints phone tokens with a fixed,
 * readable code, which is the "test hook" for local runs.
 */
export class FirebasePhoneVerifier implements PhoneVerifier {
  constructor(private readonly auth: Auth) {}

  async verify(idToken: string, now: number): Promise<{ phoneE164: string }> {
    let decoded;
    try {
      decoded = await this.auth.verifyIdToken(idToken);
    } catch {
      throw new AppError('VERIFICATION_FAILED');
    }
    const phone = decoded.phone_number;
    const ageSeconds = now / 1000 - decoded.auth_time;
    if (decoded.firebase.sign_in_provider !== 'phone' || !phone || ageSeconds > PHONE_AUTH_MAX_AGE_SECONDS || ageSeconds < -60) {
      throw new AppError('VERIFICATION_FAILED');
    }
    return { phoneE164: phone };
  }
}
