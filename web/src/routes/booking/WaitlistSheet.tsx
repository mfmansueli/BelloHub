// The waitlist (docs/10 section 3): when no time works, she leaves her name, phone and the days that suit her; the
// professional is told and offers a freed time herself. No code is asked: a waitlist entry books nothing.

import type { JSX } from 'preact';
import { useState } from 'preact/hooks';

import { api } from '../../api/client';
import type { PublicProfile } from '../../api/types';
import { Button } from '../../components/Button';
import { ErrorNotice, Notice } from '../../components/Feedback';
import { PhoneField, TextField } from '../../components/Field';
import { Sheet } from '../../components/Sheet';
import { useI18n } from '../../i18n';
import { addDays, zonedDateKey } from '../../lib/datetime';
import { normalizePhone, phoneRegion } from '../../lib/phone';

interface Props {
  readonly open: boolean;
  readonly onClose: () => void;
  readonly profile: PublicProfile;
  readonly serviceId: string | null;
}

export function WaitlistSheet({ open, onClose, profile, serviceId }: Props): JSX.Element {
  const { t, locale } = useI18n();
  const today = zonedDateKey(Date.now(), profile.timeZoneID);
  const horizon = addDays(today, profile.booking.maxDaysAhead);
  const [name, setName] = useState('');
  const [country, setCountry] = useState(profile.regionCode);
  const [phone, setPhone] = useState('');
  const [from, setFrom] = useState(today);
  const [to, setTo] = useState(addDays(today, 14));
  const [errors, setErrors] = useState<{ name?: string; phone?: string; days?: string }>({});
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);
  const [done, setDone] = useState(false);

  const submit = async (): Promise<void> => {
    const next: { name?: string; phone?: string; days?: string } = {};
    if (name.trim().length < 2) next.name = t('bk5.err.name');
    const normalized = normalizePhone(phone, phoneRegion(country));
    if (!normalized.ok) next.phone = t('bk5.err.phone');
    if (to < from) next.days = t('wait.err.days');
    setErrors(next);
    if (Object.keys(next).length > 0 || !normalized.ok || serviceId === null) return;
    setBusy(true);
    setFailure(null);
    try {
      await api.joinWaitlist({ slug: profile.slug, serviceId, name: name.trim(), phone: normalized.e164, locale, dayFrom: from, dayTo: to });
      setDone(true);
    } catch (error) {
      setFailure(error);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Sheet open={open} onClose={onClose} title={done ? t('bk4.waitJoined') : t('wait.title')} testId="waitlist-sheet" closeButton={done}>
      {done ? (
        <Notice kind="info" icon="check" live="polite" testId="waitlist-done">
          {t('bk4.waitJoinedSub', { name: profile.firstName })}
        </Notice>
      ) : (
        <form
          class="stack mt-md"
          noValidate
          onSubmit={(event) => {
            event.preventDefault();
            void submit();
          }}
        >
          <p class="lead">{t('wait.text', { name: profile.firstName })}</p>
          <TextField label={t('bk5.name')} value={name} onInput={setName} autoComplete="name" error={errors.name} testId="wait-name" />
          <PhoneField
            label={t('bk5.phone')}
            countryLabel={t('bk5.phoneCountry')}
            country={country}
            input={phone}
            defaultCountry={profile.regionCode}
            error={errors.phone}
            testId="wait-phone"
            onChange={(c, p) => { setCountry(c); setPhone(p); }}
          />
          <div class="field">
            <label for="wait-from">{t('wait.from')}</label>
            <input id="wait-from" class="input" type="date" min={today} max={horizon} value={from} onInput={(e) => { setFrom(e.currentTarget.value); }} />
          </div>
          <div class="field">
            <label for="wait-to">{t('wait.to')}</label>
            <input id="wait-to" class="input" type="date" min={today} max={horizon} value={to} aria-invalid={errors.days === undefined ? undefined : 'true'} onInput={(e) => { setTo(e.currentTarget.value); }} />
            {errors.days === undefined ? null : <p class="field-error" role="alert">{errors.days}</p>}
          </div>
          <ErrorNotice error={failure} />
          <Button busy={busy} type="submit" testId="wait-submit">
            {t('wait.submit')}
          </Button>
          <Button variant="tertiary" onClick={onClose}>
            {t('common.cancel')}
          </Button>
        </form>
      )}
    </Sheet>
  );
}
