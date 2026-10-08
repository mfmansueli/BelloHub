// "Add to calendar": a calendar file built in the browser (nothing is sent anywhere) and a Google Calendar link.
// In-app browsers often block the download, so there the page says to open it in the browser (docs/10 section 8).

import type { JSX } from 'preact';
import { useState } from 'preact/hooks';

import type { BookingView } from '../api/types';
import { useFormatter } from '../app/context';
import { useI18n } from '../i18n';
import { buildIcs, googleCalendarUrl, type CalendarEvent } from '../lib/ics';
import { inAppBrowser } from '../lib/inapp';
import { ExternalLink } from './Button';
import { Icon } from './Icon';
import { Sheet } from './Sheet';

export function calendarEvent(booking: BookingView, link: string, t: (key: string, params?: Record<string, string>) => string, language: string): CalendarEvent {
  const names = [booking.service.name, ...booking.addOns.map((addOn) => addOn.name)].join(' + ');
  return {
    uid: booking.id,
    startMs: Date.parse(booking.startsAt),
    endMs: Date.parse(booking.endsAt),
    summary: t('ics.summary', { service: names, name: booking.professional.displayName }),
    description: t('ics.change', { link }),
    ...(booking.professional.city === undefined ? {} : { location: booking.professional.city }),
    language,
  };
}

interface Props {
  readonly open: boolean;
  readonly onClose: () => void;
  readonly booking: BookingView;
  readonly link: string;
}

export function CalendarSheet({ open, onClose, booking, link }: Props): JSX.Element {
  const { t, locale } = useI18n();
  const format = useFormatter();
  const [saved, setSaved] = useState(false);
  const event = calendarEvent(booking, link, t, locale);
  const blocked = inAppBrowser();

  const download = (): void => {
    const blob = new Blob([buildIcs(event, Date.now())], { type: 'text/calendar;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = 'appointment.ics';
    document.body.append(anchor);
    anchor.click();
    anchor.remove();
    window.setTimeout(() => { URL.revokeObjectURL(url); }, 1000);
    setSaved(true);
  };

  return (
    <Sheet open={open} onClose={onClose} title={t('cal.add')} testId="calendar-sheet">
      <p class="meta">{`${format.weekdayDate(booking.startsAt)} · ${format.time(booking.startsAt)}`}</p>
      <ul class="sheet-list">
        <li>
          <button type="button" class="sheet-row" onClick={download} data-testid="ics-download">
            <Icon name="download" />
            <span class="grow">{t('cal.file')}</span>
          </button>
        </li>
        <li>
          <ExternalLink href={googleCalendarUrl(event)} class="sheet-row" testId="google-calendar">
            <Icon name="calendar" />
            <span class="grow">{t('cal.google')}</span>
          </ExternalLink>
        </li>
      </ul>
      {saved ? <p class="meta mt-sm" role="status">{t('cal.saved')}</p> : null}
      {blocked ? <p class="meta mt-sm" data-testid="inapp-note">{t('cal.inApp')}</p> : null}
    </Sheet>
  );
}
