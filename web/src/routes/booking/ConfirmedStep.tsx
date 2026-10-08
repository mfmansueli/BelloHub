// Bk-8: "You're booked." The service, the final time, the personal link (copy), add to calendar, and the health
// form when she has not sent one. The words about how the link reaches her depend on the channel (D31): with
// WhatsApp automation off the page says "save your link" (and "we emailed it" when she gave an email); only with
// automation on does it promise a WhatsApp confirmation.

import type { JSX } from 'preact';
import { useEffect, useState } from 'preact/hooks';

import type { PublicProfile } from '../../api/types';
import { useFormatter } from '../../app/context';
import { navigate, slugRoute, manageRoute } from '../../app/router';
import { allowedStep } from '../../app/booking/machine';
import { dispatchBooking, useBooking } from '../../app/booking/store';
import { bookedPriceText } from '../../app/booking/priceText';
import { CalendarSheet } from '../../components/CalendarSheet';
import { Button, Link, LinkButton } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { Avatar, Footer, Screen, Title, useDocumentTitle } from '../../components/Layout';
import { Notice, Seal } from '../../components/Feedback';
import { PersonalLink } from '../../components/PersonalLink';
import { useRules } from '../../components/RuleList';
import { useI18n } from '../../i18n';
import { linkBase } from '../../lib/config';

export function ConfirmedStep({ profile }: { profile: PublicProfile }): JSX.Element | null {
  const { t } = useI18n();
  const format = useFormatter();
  const [state] = useBooking(profile.slug, profile.regionCode);
  const rules = useRules(profile.rules, profile);
  const [calendarOpen, setCalendarOpen] = useState(false);
  useDocumentTitle(t('bk8.title'));

  const redirect = allowedStep('booked', state) !== 'booked';
  useEffect(() => {
    if (redirect) navigate(slugRoute(profile.slug), true);
  }, [redirect, profile.slug]);

  const result = state.result;
  if (redirect || result?.status !== 'confirmed') return null;
  const { booking, manageToken } = result;
  const link = `${linkBase()}/m/${manageToken}`;
  const hasEmail = state.draft.email.trim() !== '';
  const sub = profile.channels.whatsAppAutomation ? t('bk8.sub.whatsapp') : hasEmail ? t('bk8.sub.emailed') : t('bk8.sub.saveLink');
  const noShow = rules.lines.find((line) => line.kind === 'noShow')?.text;
  const changes = rules.lines.find((line) => line.kind === 'changes')?.text ?? '';
  const guestNames = booking.guestNames?.filter(Boolean) ?? [];
  const meta = [format.minutes(booking.totalMinutes), bookedPriceText(booking.price, format, t)].filter(Boolean).join(' · ');

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
          <bdi>{[booking.service.name, ...booking.addOns.map((addOn) => addOn.name)].join(' + ')}</bdi>
        </b>
        <p class="meta">{meta}</p>
        {booking.guestCount > 0 ? (
          <p class="meta">{guestNames.length > 0 ? t('bk8.guest.named', { guest: format.list(guestNames) }) : t('bk8.guest.unnamed', { count: booking.guestCount })}</p>
        ) : null}
        <hr class="rule" />
        <div class="row-flex">
          <Icon name="calendar" />
          <div>
            <b class="strong">{format.weekdayDate(booking.startsAt)}</b>
            <br />
            <span class="meta tn">{t('bk8.timeRange', { start: format.time(booking.startsAt), end: format.time(booking.endsAt) })}</span>
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

      {booking.forms.intake === 'pending' ? (
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
        <p>{t('bk8.change.text', { line: changes }).trim()}</p>
        <PersonalLink url={link} />
        {noShow === undefined ? null : (
          <Notice kind="quiet" icon="alert">
            {t('bk8.noShow', { name: profile.firstName })} {noShow}
          </Notice>
        )}
      </section>

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
      <CalendarSheet open={calendarOpen} onClose={() => { setCalendarOpen(false); }} booking={booking} link={link} />
    </Screen>
  );
}
