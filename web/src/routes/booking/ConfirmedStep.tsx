// Bk-8: "You're booked." The service, the final time, the personal link (copy), add to calendar, and the health
// form when she publishes one. The words about how the link reaches her depend on the channel (D31): with
// WhatsApp automation off the page says "save your link" (and "we emailed it" when the server did); only with
// automation on does it promise a WhatsApp confirmation. The server answers with the times and the service name
// (API.md 5.8); the add-ons, the guests and the price are what she chose, still in the draft.

import type { JSX } from 'preact';
import { useEffect, useState } from 'preact/hooks';

import { api } from '../../api/client';
import type { PublicProfile } from '../../api/types';
import { useFormatter } from '../../app/context';
import { navigate, slugRoute, manageRoute } from '../../app/router';
import { allowedStep } from '../../app/booking/machine';
import { dispatchBooking, useBooking } from '../../app/booking/store';
import { priceText } from '../../app/booking/priceText';
import { selectedAddOns, totals } from '../../app/booking/summary';
import { BookingRules } from '../../components/BookingRules';
import { CalendarSheet } from '../../components/CalendarSheet';
import { Button, Link, LinkButton } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { Avatar, Footer, Screen, Title, useDocumentTitle } from '../../components/Layout';
import { Notice, Seal } from '../../components/Feedback';
import { PersonalLink } from '../../components/PersonalLink';
import { useI18n } from '../../i18n';
import { linkBase, pageUrl } from '../../lib/config';
import type { PolicyValues } from '../../lib/policy';

export function ConfirmedStep({ profile }: { profile: PublicProfile }): JSX.Element | null {
  const { t } = useI18n();
  const format = useFormatter();
  const [state] = useBooking(profile.slug, profile.regionCode);
  const [calendarOpen, setCalendarOpen] = useState(false);
  // D47: the rules shown here are the booking's own policy snapshot, read back from the server; until it arrives (or if
  // it cannot be read) nothing is claimed.
  const [snapshot, setSnapshot] = useState<PolicyValues | null>(null);
  const bookedToken = state.result?.status === 'confirmed' ? state.result.manageToken : null;
  useEffect(() => {
    if (bookedToken === null) return;
    let current = true;
    api.getBooking(bookedToken).then(
      (booking) => {
        if (current) setSnapshot(booking.policy);
      },
      () => {
        if (current) setSnapshot(null);
      },
    );
    return () => {
      current = false;
    };
  }, [bookedToken]);
  useDocumentTitle(t('bk8.title'));

  const redirect = allowedStep('booked', state) !== 'booked';
  useEffect(() => {
    if (redirect) navigate(slugRoute(profile.slug), true);
  }, [redirect, profile.slug]);

  const result = state.result;
  if (redirect || result?.status !== 'confirmed') return null;
  const { draft } = state;
  const { manageToken } = result;
  const link = `${linkBase()}/m/${manageToken}`;
  const sub = profile.features.whatsAppAutomation ? t('bk8.sub.whatsapp') : result.emailSent ? t('bk8.sub.emailed') : t('bk8.sub.saveLink');
  const service = profile.services.find((candidate) => candidate.id === draft.serviceId);
  const addOns = selectedAddOns(profile.addOns, draft.addOnIds);
  const summary = service === undefined ? null : totals(service, addOns, draft.guests);
  const minutes = Math.round((Date.parse(result.endsAt) - Date.parse(result.startsAt)) / 60_000);
  const meta = [format.minutes(minutes), priceText(summary?.price ?? null, format, t)].filter(Boolean).join(' · ');
  const serviceNames = [result.serviceName, ...addOns.map((addOn) => addOn.name)];

  return (
    <Screen>
      <div class="stack">
        <Seal tone="rose" />
        <Title>{t('bk8.title')}</Title>
        <p class="lead" data-testid="confirmation-sub">
          {sub}
        </p>
      </div>

      <section class="card" aria-label={t('bk8.summary')} data-testid="booking-card">
        <b class="strong section">
          <bdi>{serviceNames.join(' + ')}</bdi>
        </b>
        <p class="meta">{meta}</p>
        {draft.guests > 0 ? (
          <p class="meta">{t('bk8.guest.unnamed', { count: draft.guests })}</p>
        ) : null}
        <hr class="rule" />
        <div class="row-flex">
          <Icon name="calendar" />
          <div>
            <b class="strong">{format.weekdayDate(result.startsAt)}</b>
            <br />
            <span class="meta tn">{t('bk8.timeRange', { start: format.time(result.startsAt), end: format.time(result.endsAt) })}</span>
          </div>
        </div>
        <div class="row-flex mt-md">
          <Avatar name={profile.displayName} photo={profile.photo} size="sm" />
          <div>
            <b class="strong">
              <bdi>{profile.displayName}</bdi>
            </b>
            {profile.city === undefined ? null : (
              <>
                <br />
                <span class="meta">
                  <bdi>{profile.city}</bdi>
                </span>
              </>
            )}
          </div>
        </div>
      </section>

      <div class="stack-sm">
        <LinkButton to={manageRoute(manageToken)} testId="view-appointment">
          {t('bk8.view')}
        </LinkButton>
        <Button variant="secondary" onClick={() => { setCalendarOpen(true); }} testId="add-calendar">
          <Icon name="calendarPlus" />
          {t('cal.add')}
        </Button>
      </div>

      {profile.intakeAvailable ? (
        <Link to={manageRoute(manageToken, 'form')} class="card list-row" testId="health-form">
          <span class="grow">
            <b class="strong">{t('bk8.form.title')}</b>
            <span class="sub">{t('bk8.form.text', { name: profile.firstName })}</span>
          </span>
          <Icon name="chevron" class="icon-quiet" />
        </Link>
      ) : null}

      <section class="well stack-sm" aria-labelledby="change-title">
        <h2 id="change-title" class="strong">
          {t('bk8.change.title')}
        </h2>
        <p>{t('bk8.change.text', { line: '' }).trim()}</p>
        <PersonalLink url={link} />
        <Notice kind="quiet" icon="alert">
          {t('bk8.noShow', { name: profile.firstName })}
        </Notice>
      </section>

      {snapshot === null ? null : <BookingRules policy={snapshot} professionalFirstName={profile.firstName} />}

      <p class="center">
        <Button
          variant="tertiary"
          inline
          testId="back-to-page"
          onClick={() => {
            // A finished attempt: the next booking starts clean.
            dispatchBooking(profile.slug, profile.regionCode, { type: 'reset' });
            navigate(slugRoute(profile.slug));
          }}
        >
          {t('bk8.again', { name: profile.displayName })}
        </Button>
      </p>
      <Footer />
      <CalendarSheet
        open={calendarOpen}
        onClose={() => { setCalendarOpen(false); }}
        booking={{ bookingId: result.bookingId, startsAt: result.startsAt, endsAt: result.endsAt, serviceNames, professional: { displayName: profile.displayName, city: profile.city } }}
        pageUrl={pageUrl(profile.slug)}
      />
    </Screen>
  );
}
