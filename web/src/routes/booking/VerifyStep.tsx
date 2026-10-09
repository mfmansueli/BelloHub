// Bk-6: a six-digit code by SMS or email (D31, D37). SMS is the default, email is always offered when she gave one
// ("Use email instead"), the code is never stored, and a code typed in any digit system is accepted.

import type { JSX } from 'preact';
import { useEffect, useRef, useState } from 'preact/hooks';

import type { PublicProfile } from '../../api/types';
import { useFormatter } from '../../app/context';
import { navigate, slugRoute } from '../../app/router';
import { allowedStep, FLOW_STEPS, proofTarget } from '../../app/booking/machine';
import { useBooking } from '../../app/booking/store';
import { Button } from '../../components/Button';
import { Chip } from '../../components/Choices';
import { ErrorNotice } from '../../components/Feedback';
import { CodeField } from '../../components/Field';
import { Screen, Title, TopBar, useDocumentTitle } from '../../components/Layout';
import { useI18n } from '../../i18n';
import { ltr } from '../../lib/bidi';
import { lastFour, maskEmail, normalizePhone, phoneRegion } from '../../lib/phone';
import { useVerification } from './useVerification';

export function VerifyStep({ profile }: { profile: PublicProfile }): JSX.Element | null {
  const { t, locale } = useI18n();
  const format = useFormatter();
  const [state, dispatch] = useBooking(profile.slug, profile.regionCode);
  const { draft } = state;
  useDocumentTitle(t('bk6.title'));

  const redirect = allowedStep('verify', state) !== 'verify';
  useEffect(() => {
    if (redirect) navigate(slugRoute(profile.slug, 'you'), true);
  }, [redirect, profile.slug]);

  const phone = normalizePhone(draft.phoneInput, phoneRegion(draft.phoneCountry));
  // Email codes are always offered (API.md 5.5); a NOT_CONFIGURED answer shows as an error on sending.
  const emailAvailable = draft.email.trim() !== '';
  const channel = draft.channel === 'email' && emailAvailable ? 'email' : 'sms';
  const captcha = useRef<HTMLDivElement>(null);
  const verification = useVerification({
    target: channel === 'email' ? { kind: 'email', email: draft.email.trim() } : { kind: 'sms', phone: phone.ok ? phone.e164 : '' },
    slug: profile.slug,
    locale,
    purpose: 'booking',
    captcha,
  });

  const [code, setCode] = useState('');

  if (redirect || !phone.ok) return null;

  const via = channel === 'email' ? t('bk6.viaEmail', { email: ltr(maskEmail(draft.email.trim())) }) : t('bk6.viaSms', { last: ltr(lastFour(phone.e164)) });

  const codeError = ((): string | undefined => {
    switch (verification.error?.code) {
      case 'codeInvalid':
        return t('bk6.err.invalid');
      case 'codeExpired':
        return t('bk6.err.expired');
      case 'tooManyAttempts':
      case 'rateLimited':
        return t('bk6.err.attempts');
      default:
        return undefined;
    }
  })();

  const verify = async (): Promise<void> => {
    if (code.length !== 6) return;
    const proof = await verification.confirm(code);
    if (proof === null) return;
    dispatch({ type: 'verified', proof, target: proofTarget(draft) });
    navigate(slugRoute(profile.slug, 'firstVisit'));
  };

  const switchTo = (next: 'sms' | 'email'): void => {
    setCode('');
    dispatch({ type: 'setChannel', channel: next });
  };

  return (
    <Screen
      top={<TopBar back={slugRoute(profile.slug, 'you')} step={{ current: 4, total: FLOW_STEPS }} />}
      bar={
        <Button busy={verification.confirming} disabled={code.length !== 6} onClick={() => { void verify(); }} testId="verify">
          {t('bk6.verify')}
        </Button>
      }
    >
      <div>
        <Title>{t('bk6.title')}</Title>
        <p class="lead" data-testid="via" aria-live="polite">
          {verification.status === 'sending' ? t('bk6.sending') : via}
        </p>
      </div>

      <form
        class="stack"
        noValidate
        onSubmit={(event) => {
          event.preventDefault();
          void verify();
        }}
      >
        <CodeField label={t('bk6.code')} value={code} onInput={setCode} error={codeError} />
      </form>

      <div class="stack-sm">
        <div class="row-flex">
          {verification.seconds > 0 ? (
            <p class="meta grow" role="timer" data-testid="resend-timer">
              {t('bk6.resendIn', { time: ltr(format.countdown(verification.seconds)) })}
            </p>
          ) : (
            <Button variant="tertiary" inline onClick={verification.send} testId="resend">
              {t('bk6.resend')}
            </Button>
          )}
        </div>
        <div class="chips" role="group" aria-label={t('bk6.channel')}>
          <Chip pressed={channel === 'sms'} onToggle={() => { switchTo('sms'); }} testId="use-sms">
            {t('bk6.useSms')}
          </Chip>
          {emailAvailable ? (
            <Chip pressed={channel === 'email'} onToggle={() => { switchTo('email'); }} testId="use-email">
              {t('bk6.useEmail')}
            </Chip>
          ) : null}
        </div>
        {emailAvailable ? null : <p class="foot-note">{t('bk6.emailHint')}</p>}
      </div>

      <div aria-live="polite">
        {verification.status === 'failed' && codeError === undefined ? <ErrorNotice error={verification.error} /> : null}
      </div>
      {/* Where Firebase Auth may draw its invisible reCAPTCHA. */}
      <div ref={captcha} />
    </Screen>
  );
}
