// Bk-11: "Find my appointment". She types the phone she booked with, receives a code (so only she can open it),
// and sees her upcoming bookings with this professional, each one opening its personal link. The answer is the same
// whether or not that number is a client until she has proved she holds it (docs/10 section 10).

import type { JSX } from 'preact';
import { useRef, useState } from 'preact/hooks';

import { api } from '../../api/client';
import type { FoundBooking, PublicProfile } from '../../api/types';
import { useFormatter } from '../../app/context';
import { manageRoute, slugRoute } from '../../app/router';
import { Button, ExternalLink, Link } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { ErrorNotice } from '../../components/Feedback';
import { CodeField, PhoneField } from '../../components/Field';
import { Screen, Title, TopBar, useDocumentTitle } from '../../components/Layout';
import { useI18n } from '../../i18n';
import { ltr } from '../../lib/bidi';
import { normalizePhone, phoneRegion } from '../../lib/phone';
import { whatsAppUrl } from '../../lib/whatsapp';
import { useVerification } from './useVerification';

type Step = { name: 'phone' } | { name: 'code'; phone: string } | { name: 'list'; bookings: FoundBooking[] };

export function FindPage({ profile }: { profile: PublicProfile }): JSX.Element {
  const { t } = useI18n();
  const [step, setStep] = useState<Step>({ name: 'phone' });
  useDocumentTitle(t('bk11.title'));
  return (
    <Screen top={<TopBar back={slugRoute(profile.slug)} backLabel={t('bk11.page', { name: profile.displayName })} />}>
      {step.name === 'phone' ? <PhoneStep profile={profile} onSend={(phone) => { setStep({ name: 'code', phone }); }} /> : null}
      {step.name === 'code' ? <CodeStep profile={profile} phone={step.phone} onFound={(bookings) => { setStep({ name: 'list', bookings }); }} /> : null}
      {step.name === 'list' ? <ListStep profile={profile} bookings={step.bookings} /> : null}
    </Screen>
  );
}

function PhoneStep({ profile, onSend }: { profile: PublicProfile; onSend: (phone: string) => void }): JSX.Element {
  const { t } = useI18n();
  const [country, setCountry] = useState(profile.regionCode);
  const [input, setInput] = useState('');
  const [error, setError] = useState<string | undefined>();
  const send = (): void => {
    const phone = normalizePhone(input, phoneRegion(country));
    if (!phone.ok) {
      setError(t('bk5.err.phone'));
      return;
    }
    onSend(phone.e164);
  };
  return (
    <>
      <div class="stack">
        <Title>{t('bk11.title')}</Title>
        <p class="lead">{t('bk11.sub')}</p>
      </div>
      <form class="stack" noValidate onSubmit={(event) => { event.preventDefault(); send(); }}>
        <PhoneField label={t('bk5.phone')} countryLabel={t('bk5.phoneCountry')} country={country} input={input} defaultCountry={profile.regionCode} error={error} onChange={(c, p) => { setCountry(c); setInput(p); setError(undefined); }} />
        <p class="well well-icon">
          <Icon name="lock" />
          <span>{t('bk11.note')}</span>
        </p>
        <Button type="submit" testId="send-code">
          {t('bk11.send')}
        </Button>
      </form>
    </>
  );
}

function CodeStep({ profile, phone, onFound }: { profile: PublicProfile; phone: string; onFound: (bookings: FoundBooking[]) => void }): JSX.Element {
  const { t, locale } = useI18n();
  const format = useFormatter();
  const captcha = useRef<HTMLDivElement>(null);
  const verification = useVerification({ target: { kind: 'sms', phone }, slug: profile.slug, locale, purpose: 'find', captcha });
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);

  const find = async (): Promise<void> => {
    if (code.length !== 6) return;
    const proof = await verification.confirm(code);
    if (proof === null) return;
    setBusy(true);
    setFailure(null);
    try {
      onFound(await api.findBookings(profile.slug, proof));
    } catch (error) {
      setFailure(error);
      setBusy(false);
    }
  };

  const codeError =
    verification.error?.code === 'codeInvalid' ? t('bk6.err.invalid') : verification.error?.code === 'codeExpired' ? t('bk6.err.expired') : verification.error?.code === 'tooManyAttempts' ? t('bk6.err.attempts') : undefined;

  return (
    <>
      <div class="stack">
        <Title>{t('bk6.title')}</Title>
        <p class="lead" aria-live="polite">{t('bk11.codeSub', { phone: ltr(phone) })}</p>
      </div>
      <form class="stack" noValidate onSubmit={(event) => { event.preventDefault(); void find(); }}>
        <CodeField label={t('bk11.code')} value={code} onInput={setCode} error={codeError} />
        {verification.seconds > 0 ? (
          <p class="meta" role="timer">{t('bk6.resendIn', { time: ltr(format.countdown(verification.seconds)) })}</p>
        ) : (
          <Button variant="tertiary" inline onClick={verification.send}>
            {t('bk6.resend')}
          </Button>
        )}
        {verification.status === 'failed' && codeError === undefined ? <ErrorNotice error={verification.error} /> : null}
        <ErrorNotice error={failure} />
        <Button busy={busy || verification.confirming} disabled={code.length !== 6} type="submit" testId="find">
          {t('bk11.find')}
        </Button>
      </form>
      <div ref={captcha} />
    </>
  );
}

function ListStep({ profile, bookings }: { profile: PublicProfile; bookings: FoundBooking[] }): JSX.Element {
  const { t } = useI18n();
  const format = useFormatter();
  const message = whatsAppUrl(profile.whatsappE164, t('wa.hello', { name: profile.firstName }));
  return (
    <>
      <div class="stack">
        <Title>{bookings.length > 0 ? t('bk11.found') : t('bk11.noneTitle')}</Title>
        <p class="lead" data-testid="found-count">
          {bookings.length > 0 ? t('bk11.count', { count: bookings.length, name: profile.firstName }) : t('bk11.none')}
        </p>
      </div>
      <ul class="stack">
        {bookings.map((booking) => (
          <li key={booking.manageToken}>
            <Link to={manageRoute(booking.manageToken)} class="card list-row" testId="found-booking">
              <span class="grow">
                <span class="meta">{format.weekdayDate(booking.startsAt)}</span>
                <b class="moment tn">{format.time(booking.startsAt)}</b>
                <b class="strong">
                  <bdi>{booking.serviceName}</bdi>
                </b>
                <span class="sub">
                  {t('bk9.with', { name: booking.professionalName, meta: format.minutes(booking.totalMinutes) })}
                </span>
                <span class="strong rose">{t('bk11.open')}</span>
              </span>
              <Icon name="chevron" class="icon-quiet" />
            </Link>
          </li>
        ))}
      </ul>
      {bookings.length > 0 ? <p class="well well-icon"><Icon name="link" /><span>{t('bk11.keepLink')}</span></p> : null}
      <p class="foot-note">{t('bk11.notExpected', { name: profile.firstName })}</p>
      {message === null ? null : (
        <ExternalLink href={message} variant="secondary" testId="message-pro">
          {t('bk1.messageWa', { name: profile.firstName })}
        </ExternalLink>
      )}
      <LinkBack profile={profile} />
    </>
  );
}

function LinkBack({ profile }: { profile: PublicProfile }): JSX.Element {
  const { t } = useI18n();
  return (
    <Link to={slugRoute(profile.slug)} class="btn btn-tertiary" testId="back-to-page">
      {t('bk11.back', { name: profile.displayName })}
    </Link>
  );
}
