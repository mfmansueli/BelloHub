// Bk-1: the professional's public page (docs/10 section 2). Profile, credentials, services, her rules, "Already
// booked? Find my appointment", and the notice when she has paused online booking.

import type { JSX } from 'preact';
import { useState } from 'preact/hooks';

import type { PublicProfile } from '../../api/types';
import { useFormatter } from '../../app/context';
import { navigate, slugRoute } from '../../app/router';
import { dispatchBooking } from '../../app/booking/store';
import { priceText } from '../../app/booking/priceText';
import { servicePrice } from '../../app/booking/summary';
import { Button, ExternalLink, Link } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { Avatar, Footer, Screen, useDocumentTitle } from '../../components/Layout';
import { Notice } from '../../components/Feedback';
import { LanguageChooser } from '../../components/LanguageSheet';
import { LegalDocumentView } from '../../components/Legal';
import { RuleList, useRules } from '../../components/RuleList';
import { Sheet } from '../../components/Sheet';
import { useI18n } from '../../i18n';
import { whatsAppUrl } from '../../lib/whatsapp';

export function BookingHome({ profile }: { profile: PublicProfile }): JSX.Element {
  const { t } = useI18n();
  const format = useFormatter();
  const [credentialsOpen, setCredentialsOpen] = useState(false);
  const [noticeOpen, setNoticeOpen] = useState(false);
  const rules = useRules(profile.rules, profile);
  useDocumentTitle(profile.displayName);

  const accepting = profile.booking.acceptingBookings;
  const credentials = profile.credentials;

  const pauseText =
    profile.booking.pausedUntil === undefined
      ? t('bk1.paused.unsure')
      : t('bk1.paused.back', { date: format.longDate(profile.booking.pausedUntil), name: profile.firstName });
  const message = whatsAppUrl(profile.whatsappE164, t('wa.hello', { name: profile.firstName }));

  const bar = accepting ? (
    <Link to={slugRoute(profile.slug, 'service')} class="btn btn-primary" testId="book">
      {t('bk1.book')}
    </Link>
  ) : message === null ? undefined : (
    <ExternalLink href={message} variant="primary" testId="message-pro">
      {t('bk1.messageWa', { name: profile.firstName })}
    </ExternalLink>
  );

  return (
    <Screen bar={bar}>
      <LanguageChooser offered={profile.locales} />

      <div class="hero-head">
        <Avatar name={profile.displayName} photo={profile.photo} size="lg" />
        <h1 id="page-title" class="title" tabIndex={-1}>
          <bdi>{profile.displayName}</bdi>
        </h1>
        {profile.businessName === undefined ? null : (
          <p class="lead">
            <bdi>{profile.businessName}</bdi>
          </p>
        )}
        {profile.bio === undefined || profile.bio === '' ? null : (
          <p class="lead bio">
            {profile.bio}
          </p>
        )}
      </div>

      {accepting ? null : (
        <Notice kind="warning" title={t('bk1.paused.title', { name: profile.firstName })} live="polite" testId="paused">
          {pauseText}
        </Notice>
      )}

      {credentials.length === 0 ? null : (
        <button type="button" class="card list-row" onClick={() => { setCredentialsOpen(true); }} aria-haspopup="dialog" data-testid="credentials-open">
          <span class="grow">
            <b class="strong">{t('bk1.credentials')}</b>
            <span class="sub">
              {t('bk1.credentialsCount', { count: credentials.length, name: profile.firstName })}
            </span>
          </span>
          <Icon name="chevron" class="icon-quiet" />
        </button>
      )}

      <section aria-labelledby="services-title">
        <h2 id="services-title" class="section">
          {t('bk1.services')}
        </h2>
        <ul class="card card-flush list mt-sm" data-testid="services">
          {profile.services.map((service) => (
            <li key={service.id}>
              <button
                type="button"
                class="list-row"
                data-testid={`service-${service.id}`}
                disabled={!accepting}
                onClick={() => {
                  dispatchBooking(profile.slug, profile.regionCode, { type: 'preselect', serviceId: service.id });
                  navigate(slugRoute(profile.slug, 'service'));
                }}
              >
                <span class="grow">
                  <bdi class="strong">{service.name}</bdi>
                  <span class="sub">{format.minutes(service.durationMinutes)}</span>
                </span>
                <span class="end">{priceText(servicePrice(service), format, t)}</span>
              </button>
            </li>
          ))}
        </ul>
      </section>

      {rules.lines.length === 0 ? null : (
        <section class="card" aria-labelledby="rules-title">
          <h2 id="rules-title" class="strong">
            {t('bk1.rules')}
          </h2>
          <div class="mt-sm">
            <RuleList lines={rules.lines} lang={rules.lang} />
          </div>
        </section>
      )}

      <Link to={slugRoute(profile.slug, 'find')} class="list-row well" testId="find-link">
        <span class="grow strong">{t('bk1.find')}</span>
        <Icon name="chevron" class="icon-quiet" />
      </Link>

      <p class="center">
        <Button variant="tertiary" inline onClick={() => { setNoticeOpen(true); }} testId="notice-open">
          {t('legal.noticeLink')}
        </Button>
      </p>
      <Footer />

      <Sheet open={credentialsOpen} onClose={() => { setCredentialsOpen(false); }} title={t('bk1.credentials')} testId="credentials-sheet">
        <ul class="card card-flush list mt-sm">
          {credentials.map((item, index) => (
            <li key={index} class="list-row">
              <Icon name="shield" />
              <span class="grow">
                <bdi class="strong">{item.title}</bdi>
                <span class="sub">
                  <bdi>{[item.institution, item.year === undefined ? undefined : format.plain(item.year)].filter(Boolean).join(' · ')}</bdi>
                </span>
              </span>
            </li>
          ))}
        </ul>
      </Sheet>
      <Sheet open={noticeOpen} onClose={() => { setNoticeOpen(false); }} title={t('legal.noticeLink')} testId="notice-sheet">
        <LegalDocumentView document="client-notice" professionalName={profile.displayName} />
      </Sheet>
    </Screen>
  );
}
