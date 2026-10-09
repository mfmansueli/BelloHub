// Bk-10: "Maria will confirm this one." The booking was created and waits for the professional. The server never
// says why (API.md 5.8: a new client, the free registrations, or missed appointments all look the same), so the
// page says only that she confirms it herself, and nothing about money or limits (D42). And the other case: online booking is
// paused for this client only, with a way to message her.

import type { JSX } from 'preact';
import { useEffect, useState } from 'preact/hooks';

import type { PublicProfile } from '../../api/types';
import { useFormatter } from '../../app/context';
import { navigate, slugRoute } from '../../app/router';
import { allowedStep } from '../../app/booking/machine';
import { dispatchBooking, useBooking } from '../../app/booking/store';
import { Button, ExternalLink } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { Notice, Seal } from '../../components/Feedback';
import { Footer, ProHeader, Screen, Title, useDocumentTitle } from '../../components/Layout';
import { useI18n } from '../../i18n';
import { whatsAppUrl } from '../../lib/whatsapp';

export function ReviewStep({ profile }: { profile: PublicProfile }): JSX.Element | null {
  const { t } = useI18n();
  const format = useFormatter();
  const [state] = useBooking(profile.slug, profile.regionCode);
  const [why, setWhy] = useState(false);
  const result = state.result;
  useDocumentTitle(result?.status === 'paused' ? t('bk10.blocked.title') : t('bk10.title', { name: profile.firstName }));

  const redirect = allowedStep('review', state) !== 'review';
  useEffect(() => {
    if (redirect) navigate(slugRoute(profile.slug), true);
  }, [redirect, profile.slug]);
  if (redirect || result === null) return null;

  const backToPage = (): void => {
    dispatchBooking(profile.slug, profile.regionCode, { type: 'reset' });
    navigate(slugRoute(profile.slug));
  };

  if (result.status === 'paused') {
    const message = whatsAppUrl(profile.whatsappE164, t('wa.blocked', { name: profile.firstName }));
    return (
      <Screen
        top={<header class="topbar"><ProHeader professional={profile} /></header>}
        bar={
          message === null ? undefined : (
            <ExternalLink href={message} variant="primary" testId="message-pro">
              {t('bk1.messageWa', { name: profile.firstName })}
            </ExternalLink>
          )
        }
      >
        <div class="stack">
          <Title>{t('bk10.blocked.title')}</Title>
          <p class="lead" data-testid="blocked-text">{t('bk10.blocked.text', { name: profile.firstName })}</p>
        </div>
        <div class="stack-sm">
          <button type="button" class="btn btn-secondary" aria-expanded={why ? 'true' : 'false'} aria-controls="why" onClick={() => { setWhy((value) => !value); }} data-testid="why">
            {t('bk10.why')}
            <Icon name="chevron" />
          </button>
          {why ? (
            <div id="why" class="well stack-sm" data-testid="why-text">
              <p>{t('bk10.whyText', { name: profile.firstName, window: format.hours(profile.policy.freeWindowHours) })}</p>
              <p>{t('bk10.whyMore', { name: profile.firstName })}</p>
            </div>
          ) : null}
        </div>
        <Button variant="tertiary" onClick={backToPage}>
          {t('bk10.back', { name: profile.displayName })}
        </Button>
        <Footer />
      </Screen>
    );
  }

  const draft = state.draft;
  const service = profile.services.find((candidate) => candidate.id === draft.serviceId);
  return (
    <Screen top={<header class="topbar"><ProHeader professional={profile} /></header>}>
      <div class="stack">
        <Seal tone="amber" />
        <Title>{t('bk10.title', { name: profile.firstName })}</Title>
        <p class="lead" data-testid="review-reason">
          {t('bk10.reason.newClient', { name: profile.firstName })}
        </p>
      </div>

      {service === undefined || draft.startsAt === null ? null : (
        <section class="card" aria-labelledby="request-title">
          <h2 id="request-title" class="meta">
            {t('bk10.request')}
          </h2>
          <b class="strong section">
            <bdi>{service.name}</bdi>
          </b>
          <p class="meta tn">{`${format.longDate(draft.startsAt)} · ${format.time(draft.startsAt)}`}</p>
        </section>
      )}

      <Notice kind="info" icon="check" live="polite" title={t('bk10.sent')} testId="request-sent">
        {t('bk10.sentText', { name: profile.firstName })}
      </Notice>

      <Button variant="secondary" onClick={backToPage} testId="back-to-page">
        {t('bk10.back', { name: profile.displayName })}
      </Button>
      <Footer />
    </Screen>
  );
}
