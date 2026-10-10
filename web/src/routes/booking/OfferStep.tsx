// The waiting-list offer link (docs/10 section 3, API.md 5.4): the professional kept a time for someone on her waiting
// list and sent `/{slug}/time?offer=<holdKey>`. The page reads what she kept (service, add-ons, guests, time), puts it
// in the draft with her key, and goes straight to "you"; booking with that key converts her hold (5.8). An offer
// that expired or was taken says so plainly and leads to the normal free times.

import type { JSX } from 'preact';
import { useEffect, useState } from 'preact/hooks';

import { api } from '../../api/client';
import { ApiError } from '../../api/errors';
import type { PublicProfile } from '../../api/types';
import { navigate, slugRoute } from '../../app/router';
import { dispatchBooking } from '../../app/booking/store';
import { ErrorNotice, FullState, SkeletonScreen } from '../../components/Feedback';
import { useI18n } from '../../i18n';

type Load = { readonly status: 'loading' } | { readonly status: 'gone' } | { readonly status: 'error'; readonly error: unknown };

export function OfferStep({ profile, holdKey }: { profile: PublicProfile; holdKey: string }): JSX.Element {
  const { t } = useI18n();
  const [load, setLoad] = useState<Load>({ status: 'loading' });
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let current = true;
    setLoad({ status: 'loading' });
    api.getHold(profile.slug, holdKey).then(
      (hold) => {
        if (!current) return;
        const offered = profile.services.some((service) => service.id === hold.serviceId);
        if (!offered || Date.parse(hold.expiresAt) <= Date.now()) {
          setLoad({ status: 'gone' });
          return;
        }
        dispatchBooking(profile.slug, profile.regionCode, { type: 'acceptOffer', hold, holdKey });
        navigate(slugRoute(profile.slug, 'you'), true);
      },
      (error: unknown) => {
        if (!current) return;
        const gone = error instanceof ApiError && (error.code === 'notFound' || error.code === 'expired');
        setLoad(gone ? { status: 'gone' } : { status: 'error', error });
      },
    );
    return () => {
      current = false;
    };
  }, [profile.slug, holdKey, attempt]);

  const otherTimes = { label: t('bk4.offer.otherTimes'), onClick: () => { navigate(slugRoute(profile.slug, 'service'), true); } };
  if (load.status === 'gone') {
    return <FullState title={t('bk4.offer.gone.title')} text={t('bk4.offer.gone.text', { name: profile.firstName })} action={otherTimes} testId="offer-gone" />;
  }
  if (load.status === 'error') {
    return (
      <FullState title={t('bk4.offer.title', { name: profile.firstName })} action={{ label: t('common.retry'), onClick: () => { setAttempt((value) => value + 1); } }} testId="offer-error">
        <ErrorNotice error={load.error} />
      </FullState>
    );
  }
  return <SkeletonScreen />;
}
