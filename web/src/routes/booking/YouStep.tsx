// Bk-5: who is coming. Name, phone (the identity), optional email, a guest's name when she brings one, and "Good to
// know" (the professional's rules, as published). No account and no password: a code confirms it is her next.

import type { JSX } from 'preact';
import { useEffect, useState } from 'preact/hooks';

import type { PublicProfile } from '../../api/types';
import { useFormatter } from '../../app/context';
import { navigate, slugRoute } from '../../app/router';
import { allowedStep, FLOW_STEPS } from '../../app/booking/machine';
import { useBooking } from '../../app/booking/store';
import { selectedAddOns, totals } from '../../app/booking/summary';
import { Button } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { Notice } from '../../components/Feedback';
import { PhoneField, TextField } from '../../components/Field';
import { Screen, Title, TopBar, useDocumentTitle } from '../../components/Layout';
import { LegalDocumentView } from '../../components/Legal';
import { Sheet } from '../../components/Sheet';
import { useI18n } from '../../i18n';
import { ltr } from '../../lib/bidi';
import { normalizePhone, phoneRegion } from '../../lib/phone';
import { useRules } from '../../components/RuleList';

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

interface Errors {
  name?: string;
  phone?: string;
  email?: string;
  guests?: string;
}

export function YouStep({ profile }: { profile: PublicProfile }): JSX.Element | null {
  const { t } = useI18n();
  const format = useFormatter();
  const [state, dispatch] = useBooking(profile.slug, profile.regionCode);
  const { draft } = state;
  const rules = useRules(profile.rules, profile);
  useDocumentTitle(t('bk5.title'));

  const redirect = allowedStep('you', state) !== 'you';
  useEffect(() => {
    if (redirect) navigate(slugRoute(profile.slug, 'time'), true);
  }, [redirect, profile.slug]);

  const [name, setName] = useState(draft.name);
  const [country, setCountry] = useState(draft.phoneCountry);
  const [phone, setPhone] = useState(draft.phoneInput);
  const [email, setEmail] = useState(draft.email);
  const [guests, setGuests] = useState<readonly string[]>(Array.from({ length: draft.guests }, (_, i) => draft.guestNames[i] ?? ''));
  const [errors, setErrors] = useState<Errors>({});
  const [noticeOpen, setNoticeOpen] = useState(false);

  if (redirect || draft.startsAt === null) return null;

  const service = profile.services.find((candidate) => candidate.id === draft.serviceId);
  const summary = service === undefined ? null : totals(service, selectedAddOns(profile.addOns, draft.addOnIds), draft.guests);

  const submit = (): void => {
    const next: Errors = {};
    if (name.trim().length < 2) next.name = t('bk5.err.name');
    if (!normalizePhone(phone, phoneRegion(country)).ok) next.phone = t('bk5.err.phone');
    if (email.trim() !== '' && !EMAIL.test(email.trim())) next.email = t('bk5.err.email');
    if (guests.some((guest) => guest.trim() === '')) next.guests = t('bk5.err.guest');
    setErrors(next);
    if (Object.keys(next).length > 0) {
      // Focus the first field with a problem so the keyboard and a screen reader land on it.
      window.setTimeout(() => {
        document.querySelector<HTMLElement>('[aria-invalid="true"]')?.focus();
      }, 0);
      return;
    }
    dispatch({ type: 'setDetails', name: name.trim(), phoneCountry: country, phoneInput: phone.trim(), email: email.trim() });
    dispatch({ type: 'setGuests', guests: draft.guests, guestNames: guests.map((guest) => guest.trim()) });
    navigate(slugRoute(profile.slug, 'verify'));
  };

  return (
    <Screen
      top={<TopBar back={slugRoute(profile.slug, 'time')} step={{ current: 3, total: FLOW_STEPS }} />}
      bar={
        <Button onClick={submit} testId="send-code">
          {t('bk5.send')}
        </Button>
      }
    >
      <div>
        <Title>{t('bk5.title')}</Title>
        <p class="lead">{t('bk5.sub', { date: format.shortDate(draft.startsAt), time: ltr(format.time(draft.startsAt)), name: profile.firstName })}</p>
      </div>

      <form
        class="stack"
        noValidate
        onSubmit={(event) => {
          event.preventDefault();
          submit();
        }}
      >
        <TextField label={t('bk5.name')} value={name} onInput={setName} autoComplete="name" error={errors.name} testId="name" />
        <PhoneField label={t('bk5.phone')} countryLabel={t('bk5.phoneCountry')} country={country} input={phone} defaultCountry={profile.regionCode} error={errors.phone} onChange={(c, p) => { setCountry(c); setPhone(p); }} />
        <TextField label={t('bk5.email')} optional value={email} onInput={setEmail} type="email" inputMode="email" autoComplete="email" placeholder="you@example.com" error={errors.email} testId="email" dir="ltr" />
        {guests.map((guest, index) => (
          <TextField
            key={index}
            label={draft.guests === 1 ? t('bk5.guestName') : t('bk5.guestNameN', { n: index + 1 })}
            value={guest}
            onInput={(value) => { setGuests((current) => current.map((existing, i) => (i === index ? value : existing))); }}
            placeholder={t('bk5.guestNamePlaceholder')}
            error={guest.trim() === '' ? errors.guests : undefined}
            testId={`guest-name-${index}`}
          />
        ))}
      </form>

      <p class="well well-icon">
        <Icon name="lock" />
        <span>{t('bk5.noAccount')}</span>
      </p>

      {draft.guests > 0 && summary !== null ? (
        <Notice kind="info" icon="clock" testId="guest-total">
          {t('bk5.guestTotal', { total: format.minutes(summary.totalMinutes), each: format.minutes(summary.perPersonMinutes), name: profile.firstName })}
        </Notice>
      ) : null}

      {rules.lines.length === 0 ? null : (
        <section class="card" aria-labelledby="good-title">
          <h2 id="good-title" class="strong">
            {t('bk5.good')}
          </h2>
          <ul class="check-list mt-sm" lang={rules.lang}>
            {rules.lines.map((line, index) => (
              <li key={index}>
                <Icon name={line.kind === 'link' ? 'link' : line.kind === 'noShow' ? 'alert' : 'clock'} />
                <span>{line.text}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <p class="foot-note">
        {t('bk5.privacy', { name: profile.displayName })}{' '}
        <button type="button" class="link-button" onClick={() => { setNoticeOpen(true); }} data-testid="notice-open">
          {t('legal.noticeLink')}
        </button>
      </p>
      <Sheet open={noticeOpen} onClose={() => { setNoticeOpen(false); }} title={t('legal.noticeLink')} testId="notice-sheet">
        <LegalDocumentView document="client-notice" professionalName={profile.displayName} />
      </Sheet>
    </Screen>
  );
}
