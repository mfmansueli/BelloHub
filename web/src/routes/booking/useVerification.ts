// One verification attempt for the page: start (send the code), count down to "send a new code", confirm. Shared by
// the booking flow (Bk-6) and "Find my appointment" (Bk-11).

import { useCallback, useEffect, useRef, useState } from 'preact/hooks';
import type { RefObject } from 'preact';

import { api } from '../../api/client';
import { ApiError } from '../../api/errors';
import type { VerificationProof } from '../../api/types';
import { createVerifier, type Verifier, type VerifyTarget } from '../../api/verifier';
import { config } from '../../lib/config';
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
  readonly target: VerifyTarget;
  readonly slug: string;
  readonly locale: LocaleId;
  readonly purpose: 'booking' | 'find';
  readonly captcha: RefObject<HTMLDivElement>;
}

/** Restarts (and sends again) whenever `target` changes. */
export function useVerification({ target, slug, locale, purpose, captcha }: Options): VerificationControls {
  const [status, setStatus] = useState<VerificationStatus>('sending');
  const [seconds, setSeconds] = useState(0);
  const [error, setError] = useState<ApiError | null>(null);
  const [confirming, setConfirming] = useState(false);
  const verifier = useRef<Verifier | null>(null);
  const targetKey = target.kind === 'sms' ? `sms|${target.phone}` : `email|${target.email}`;

  const send = useCallback((): void => {
    setStatus('sending');
    setError(null);
    const next = createVerifier(target, { api, config, slug, locale, purpose, captchaContainer: captcha.current });
    verifier.current = next;
    next.start().then(
      (response) => {
        if (verifier.current !== next) return;
        setStatus('sent');
        setSeconds(response.resendAfterSeconds);
      },
      (failure: unknown) => {
        if (verifier.current !== next) return;
        setStatus('failed');
        setError(failure instanceof ApiError ? failure : new ApiError('network'));
        if (failure instanceof ApiError && failure.retryAfterSeconds !== undefined) setSeconds(failure.retryAfterSeconds);
      },
    );
    // The verifier depends on exactly what `targetKey`, the slug, the language and the purpose spell out.
  }, [targetKey, slug, locale, purpose]);

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
    const current = verifier.current;
    if (current === null) return null;
    setConfirming(true);
    setError(null);
    try {
      return await current.confirm(code);
    } catch (failure) {
      setError(failure instanceof ApiError ? failure : new ApiError('network'));
      return null;
    } finally {
      setConfirming(false);
    }
  }, []);

  return { status, seconds, error, confirming, send, confirm };
}
