// Bk-6: a six-digit code sent to her e-mail (D46: the only way the web page verifies). The code is never stored, and
// a code typed in any digit system is accepted.
//
// When the code does not come (most often the spam folder or a mistyped address): she can correct the address right
// here, ask for a new code, and, after the first wait is over, open "I didn't get the code". That sheet repeats those
// two and, when the professional has a public WhatsApp number, offers "Confirm with <her> on WhatsApp": the booking
// is made as an unverified request (API.md 5.8, `whatsapp`) and Bk-10 prefills her WhatsApp message.

import type { JSX } from 'preact';
import { useEffect, useState } from 'preact/hooks';

import type { PublicProfile } from '../../api/types';
import { useFormatter } from '../../app/context';
import { navigate, slugRoute } from '../../app/router';
import { allowedStep, FLOW_STEPS, proofTarget } from '../../app/booking/machine';
import { useBooking } from '../../app/booking/store';
import { Button } from '../../components/Button';
import { ErrorNotice } from '../../components/Feedback';
import { CodeField, TextField } from '../../components/Field';
import { Screen, Title, TopBar, useDocumentTitle } from '../../components/Layout';
import { Sheet } from '../../components/Sheet';
import { useI18n } from '../../i18n';
import { ltr } from '../../lib/bidi';
import { isEmail } from '../../lib/email';
import { maskEmail, normalizePhone, phoneRegion } from '../../lib/phone';
import { submitUnverified } from './submit';
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
  const email = draft.email.trim();
  const verification = useVerification({ email, slug: profile.slug, locale, purpose: 'booking', holdKey: draft.holdKey });

  const [code, setCode] = useState('');
  const [editing, setEditing] = useState(false);
  const [newEmail, setNewEmail] = useState(email);
  const [emailError, setEmailError] = useState<string | undefined>(undefined);
  const [helpOpen, setHelpOpen] = useState(false);
  const [sendingWa, setSendingWa] = useState(false);
  const [waFailure, setWaFailure] = useState<unknown>(null);

  if (redirect || !phone.ok) return null;

  const via = t('bk6.viaEmail', { email: ltr(maskEmail(email)) });
  // The way out appears once the first wait is over (or she already asked again): never before a code had a chance.
  const offersHelp = verification.resends > 0 || (verification.status !== 'sending' && verification.seconds === 0);
  const canConfirmOnWhatsApp = profile.whatsappE164 !== undefined;

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

  const startEditing = (): void => {
    setHelpOpen(false);
    setNewEmail(email);
    setEmailError(undefined);
    setEditing(true);
  };

  /** A corrected address replaces the old one; the hook sends a code to it on its own. */
  const saveEmail = (): void => {
    const next = newEmail.trim();
    if (!isEmail(next)) {
      setEmailError(t('bk5.err.email'));
      return;
    }
    setEditing(false);
    setCode('');
    if (next.toLowerCase() === email.toLowerCase()) return;
    dispatch({ type: 'setDetails', name: draft.name, phoneCountry: draft.phoneCountry, phoneInput: draft.phoneInput, email: next });
  };

  const confirmOnWhatsApp = async (): Promise<void> => {
    setSendingWa(true);
    setWaFailure(null);
    try {
      await submitUnverified(profile, state, locale, dispatch);
    } catch (error) {
      setWaFailure(error);
    } finally {
      setSendingWa(false);
    }
  };

  const resendControl = (timerId: string, buttonId: string): JSX.Element =>
    verification.seconds > 0 ? (
      <p class="meta grow" role="timer" data-testid={timerId}>
        {t('bk6.resendIn', { time: ltr(format.countdown(verification.seconds)) })}
      </p>
    ) : (
      <Button variant="tertiary" inline onClick={verification.send} testId={buttonId}>
        {t('bk6.resend')}
      </Button>
    );

  return (
    <Screen
      top={<TopBar back={slugRoute(profile.slug, 'you')} step={{ current: 4, total: FLOW_STEPS }} />}
      bar={
        <Button busy={verification.confirming} disabled={code.length !== 6 || editing} onClick={() => { void verify(); }} testId="verify">
          {t('bk6.verify')}
        </Button>
      }
    >
      <div>
        <Title>{t('bk6.title')}</Title>
        <p class="lead" data-testid="via" aria-live="polite">
          {verification.status === 'sending' ? t('bk6.sending') : via}
        </p>
        {editing ? null : (
          <Button variant="tertiary" inline onClick={startEditing} testId="change-email">
            {t('bk6.changeEmail')}
          </Button>
        )}
      </div>

      {editing ? (
        <form
          class="stack-sm"
          noValidate
          onSubmit={(event) => {
            event.preventDefault();
            saveEmail();
          }}
        >
          <TextField label={t('bk5.email')} value={newEmail} onInput={setNewEmail} type="email" inputMode="email" autoComplete="email" error={emailError} testId="new-email" dir="ltr" />
          <div class="row-flex">
            <Button inline type="submit" testId="save-email">
              {t('bk6.sendToNew')}
            </Button>
            <Button inline variant="tertiary" onClick={() => { setEditing(false); }} testId="cancel-email">
              {t('bk6.keepEmail')}
            </Button>
          </div>
        </form>
      ) : (
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
      )}

      <div class="stack-sm">
        <div class="row-flex">{resendControl('resend-timer', 'resend')}</div>
        {offersHelp ? (
          <p>
            <button type="button" class="link-button" onClick={() => { setHelpOpen(true); }} data-testid="no-code">
              {t('bk6.help.link')}
            </button>
          </p>
        ) : null}
      </div>

      <div aria-live="polite">
        {verification.status === 'failed' && codeError === undefined ? <ErrorNotice error={verification.error} /> : null}
      </div>

      <Sheet open={helpOpen} onClose={() => { setHelpOpen(false); }} title={t('bk6.help.title')} testId="no-code-sheet">
        <div class="stack">
          <p data-testid="help-spam">{t('bk6.help.spam', { email: ltr(email) })}</p>
          <div class="stack-sm">
            <div class="row-flex">{resendControl('help-timer', 'help-resend')}</div>
            <Button variant="secondary" onClick={startEditing} testId="help-change-email">
              {t('bk6.changeEmail')}
            </Button>
          </div>
          {canConfirmOnWhatsApp ? (
            <section class="well stack-sm" aria-labelledby="wa-title" data-testid="help-whatsapp">
              <h3 id="wa-title" class="strong">
                {t('bk6.help.waTitle')}
              </h3>
              <p>{t('bk6.help.waText', { name: profile.firstName })}</p>
              <Button busy={sendingWa} onClick={() => { void confirmOnWhatsApp(); }} testId="confirm-whatsapp">
                {t('bk6.help.waButton', { name: profile.firstName })}
              </Button>
              <ErrorNotice error={waFailure} testId="whatsapp-error" />
            </section>
          ) : null}
        </div>
      </Sheet>
    </Screen>
  );
}
