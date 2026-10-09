// One verification attempt for the page: start (send the e-mail code), count down to "send a new code", confirm.
// Shared by the booking flow (Bk-6) and "Find my appointment" (Bk-11). D46: e-mail code only, straight through our own
// API (API.md 5.5 and 5.6); no SDK, no third-party script.

import { useCallback, useEffect, useRef, useState } from 'preact/hooks';

import { api } from '../../api/client';
import { ApiError } from '../../api/errors';
import type { VerificationProof } from '../../api/types';
import type { LocaleId } from '../../lib/locales';

export type VerificationStatus = 'sending' | 'sent' | 'failed';

export interface VerificationControls {
  readonly status: VerificationStatus;
  /** Seconds until a new code may be requested; 0 when she may ask now. */
  readonly seconds: number;
  readonly error: ApiError | null;
  readonly confirming: boolean;
  readonly send: () => void;
  readonly confirm: (code: string) => Promise<VerificationProof | null>;
}

interface Options {
  readonly email: string;
  readonly slug: string;
  readonly locale: LocaleId;
  readonly purpose: 'booking' | 'find';
}

/** Restarts (and sends again) whenever `email` changes. */
export function useVerification({ email, slug, locale, purpose }: Options): VerificationControls {
  const [status, setStatus] = useState<VerificationStatus>('sending');
  const [seconds, setSeconds] = useState(0);
  const [error, setError] = useState<ApiError | null>(null);
  const [confirming, setConfirming] = useState(false);
  const attempt = useRef<symbol | null>(null);

  const send = useCallback((): void => {
    if (email === '') return;
    setStatus('sending');
    setError(null);
    const next = Symbol('attempt');
    attempt.current = next;
    api.sendEmailCode({ slug, email, locale, purpose }).then(
      (response) => {
        if (attempt.current !== next) return;
        setStatus('sent');
        setSeconds(response.resendAfterSeconds);
      },
      (failure: unknown) => {
        if (attempt.current !== next) return;
        setStatus('failed');
        setError(failure instanceof ApiError ? failure : new ApiError('network'));
        if (failure instanceof ApiError && failure.retryAfterSeconds !== undefined) setSeconds(failure.retryAfterSeconds);
      },
    );
  }, [email, slug, locale, purpose]);

  useEffect(() => {
    send();
  }, [send]);

  useEffect(() => {
    if (seconds <= 0) return;
    const timer = window.setTimeout(() => {
      setSeconds((value) => Math.max(0, value - 1));
    }, 1000);
    return () => {
      window.clearTimeout(timer);
    };
  }, [seconds]);

  const confirm = useCallback(async (code: string): Promise<VerificationProof | null> => {
    setConfirming(true);
    setError(null);
    try {
      return { method: 'email', proof: await api.verifyEmailCode(email, code) };
    } catch (failure) {
      setError(failure instanceof ApiError ? failure : new ApiError('network'));
      return null;
    } finally {
      setConfirming(false);
    }
  }, [email]);

  return { status, seconds, error, confirming, send, confirm };
}
