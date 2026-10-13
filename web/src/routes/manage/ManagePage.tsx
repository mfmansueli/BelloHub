// Bk-9: the management page, opened from the personal link (docs/10 section 4). Right under the booking it says
// "Change or cancel" with the two actions (owner, 2026-10-11: the link must lead straight to changing or cancelling;
// it arrives in her WhatsApp message and e-mails), then only the other actions her policy allows at this moment: confirm she is coming, tell the professional she is running late,
// reschedule (directly, by request, or by message), cancel (free, or late with an honest warning, or by message),
// add to calendar, read the rules, message her. Which actions show is the SERVER's verdict (`actions` of API.md
// 5.11, evaluated from the policy stored on the booking and the server clock); lib/policy.ts only words the
// deadline. The server refuses anything the policy does not allow anyway.

import type { JSX } from 'preact';
import { useState } from 'preact/hooks';

import { api } from '../../api/client';
import type { BookingView } from '../../api/types';
import { useFormatter } from '../../app/context';
import { manageRoute, slugRoute, type Route } from '../../app/router';
import { Button, ExternalLink, Link } from '../../components/Button';
import { CalendarSheet } from '../../components/CalendarSheet';
import { ErrorNotice, Notice, StatusChip, type StatusKind } from '../../components/Feedback';
import { Chip } from '../../components/Choices';
import { Icon } from '../../components/Icon';
import { Footer, Screen, Title, TopBar, Avatar, useDocumentTitle } from '../../components/Layout';
import { PlaceCard } from '../../components/PlaceCard';
import { BookingRules } from '../../components/BookingRules';
import { PhoneField, TextField } from '../../components/Field';
import { useI18n } from '../../i18n';
import { pageUrl } from '../../lib/config';
import { isEmail } from '../../lib/email';
import { digitsOnly } from '../../lib/digits';
import { normalizePhone, phoneRegion } from '../../lib/phone';
import { freeUntil, reschedulesLeft } from '../../lib/policy';
import { forgetDeviceLocally, storedDeviceToken } from '../../lib/trustedDevice';
import { whatsAppUrl } from '../../lib/whatsapp';

const LATE_MINUTES = [10, 15, 20, 30] as const;

export function serverClock(booking: BookingView): () => number {
  const skew = Date.parse(booking.serverTime) - Date.now();
  return () => Date.now() + (Number.isFinite(skew) ? skew : 0);
}

/** A request the professional has not answered yet. */
export function openRequest(booking: BookingView): { requestedStart: string } | undefined {
  return booking.pendingReschedule?.status === 'pending' ? booking.pendingReschedule : undefined;
}

/** A visit that took place: confirmed and in the past. */
export function isCompleted(booking: BookingView): boolean {
  return booking.status === 'confirmed' && booking.phase === 'past';
}

function statusOf(booking: BookingView, attending: boolean): { kind: StatusKind; key: string } {
  if (openRequest(booking) !== undefined && booking.status === 'confirmed') return { kind: 'pending', key: 'bk9.status.changeRequested' };
  switch (booking.status) {
    case 'confirmed':
      if (isCompleted(booking)) return { kind: 'done', key: 'bk9.status.completed' };
      return attending || booking.clientConfirmedAt !== undefined ? { kind: 'confirmed', key: 'bk9.status.willBeThere' } : { kind: 'confirmed', key: 'bk9.status.confirmed' };
    case 'pendingApproval':
      return { kind: 'pending', key: 'bk9.status.pending' };
    case 'cancelledByClient':
      return { kind: 'done', key: 'bk9.status.cancelled' };
    case 'cancelledByPro':
      return { kind: 'attention', key: 'bk9.status.cancelledByPro' };
    case 'declined':
      return { kind: 'attention', key: 'bk9.status.declined' };
    case 'noShow':
      return { kind: 'attention', key: 'bk9.status.noShow' };
  }
}

interface Props {
  readonly token: string;
  readonly booking: BookingView;
}

export function ManagePage({ token, booking }: Props): JSX.Element {
  const { t } = useI18n();
  const format = useFormatter();
  const pro = booking.professional;
  const now = serverClock(booking)();
  const startsAt = Date.parse(booking.startsAt);
  const endsAt = Date.parse(booking.endsAt);
  const policy = booking.policy;
  const [email, setEmail] = useState('');
  const [confirmEmail, setConfirmEmail] = useState('');
  const [phoneCountry, setPhoneCountry] = useState(pro.regionCode);
  const [phone, setPhone] = useState('');
  const [confirmPhone, setConfirmPhone] = useState('');
  const [fieldErrors, setFieldErrors] = useState<{
    email?: string;
    confirmEmail?: string;
    phone?: string;
    confirmPhone?: string;
  }>({});
  const [calendarOpen, setCalendarOpen] = useState(false);
  const [attend, setAttend] = useState<'yes' | 'no' | null>(null);
  const [late, setLate] = useState<number | null>(booking.lateByMinutes ?? null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);
  useDocumentTitle(t('bk9.title'));

  const status = statusOf(booking, attend === 'yes');
  const active = (booking.status === 'confirmed' || booking.status === 'pendingApproval') && booking.phase !== 'past' && now < endsAt;
  const gone = booking.status === 'cancelledByClient' || booking.status === 'cancelledByPro' || booking.status === 'declined';
  const place = pro.city ?? pro.timeZoneID.split('/').at(-1)?.replace(/_/g, ' ') ?? pro.timeZoneID;

  const { actions } = booking;
  const cancel = actions.cancel;
  const resched = actions.reschedule;
  const left = reschedulesLeft(policy, booking.rescheduleCount);
  const deadline = `${format.shortDate(freeUntil(startsAt, policy))} · ${format.time(freeUntil(startsAt, policy))}`;
  const dateAndTime = { date: format.dayMonth(startsAt), time: format.time(startsAt) };
  const message = (key: string): string | null => whatsAppUrl(pro.whatsappE164, t(key, { name: pro.firstName, service: booking.service.name, ...dateAndTime }));

  const showAttend = actions.canConfirmPresence && booking.clientConfirmedAt === undefined && openRequest(booking) === undefined;
  const showLate = actions.canReportLate && now <= endsAt;

  const confirmPresence = async (): Promise<void> => {
    const errors: {
      email?: string;
      confirmEmail?: string;
      phone?: string;
      confirmPhone?: string;
    } = {};

    const trimmedEmail = email.trim().toLowerCase();
    const trimmedConfirmEmail = confirmEmail.trim().toLowerCase();
    const hasEmail = trimmedEmail.length > 0 || trimmedConfirmEmail.length > 0;

    if (hasEmail) {
      if (!trimmedEmail || !isEmail(trimmedEmail)) {
        errors.email = t('bk5.err.email');
      }
      if (!trimmedConfirmEmail || trimmedEmail !== trimmedConfirmEmail) {
        errors.confirmEmail = t('bk9.attend.err.emailMismatch');
      }
    }

    const trimmedPhone = phone.trim();
    const trimmedConfirmPhone = confirmPhone.trim();
    const hasPhone = trimmedPhone.length > 0 || trimmedConfirmPhone.length > 0;
    let normalizedPhoneE164: string | undefined;

    if (hasPhone) {
      const norm = normalizePhone(trimmedPhone, phoneRegion(phoneCountry));
      if (!norm.ok) {
        errors.phone = t('bk5.err.phone');
      } else {
        normalizedPhoneE164 = norm.e164;
      }
      const phoneDigits = digitsOnly(trimmedPhone);
      const confirmDigits = digitsOnly(trimmedConfirmPhone);
      if (!confirmDigits || phoneDigits !== confirmDigits) {
        errors.confirmPhone = t('bk9.attend.err.phoneMismatch');
      }
    }

    setFieldErrors(errors);
    if (Object.keys(errors).length > 0) return;

    setBusy(true);
    setFailure(null);
    try {
      const clientPayload: { email?: string; phone?: string } = {};
      if (trimmedEmail) clientPayload.email = trimmedEmail;
      if (normalizedPhoneE164) clientPayload.phone = normalizedPhoneE164;
      await api.confirmPresence(token, Object.keys(clientPayload).length > 0 ? clientPayload : undefined);
      setAttend('yes');
    } catch (error) {
      setFailure(error);
    } finally {
      setBusy(false);
    }
  };

  const reportLate = async (minutes: number): Promise<void> => {
    setBusy(true);
    setFailure(null);
    try {
      const response = await api.reportLate(token, minutes);
      setLate(response.lateByMinutes);
    } catch (error) {
      setFailure(error);
    } finally {
      setBusy(false);
    }
  };

  const resSub = ((): string => {
    if (resched === 'message' || resched === 'unavailable') return t('bk9.reschedule.message', { name: pro.firstName });
    if (resched === 'request') return t('bk9.reschedule.request', { name: pro.firstName });
    return left === null ? t('bk9.reschedule.direct') : t('bk9.reschedule.directLimit', { count: left });
  })();
  const cancelSub = ((): string => {
    if (cancel === 'free') return t('bk9.cancel.free', { deadline });
    if (cancel === 'askByMessage' || cancel === 'unavailable') return t('bk9.cancel.message', { name: pro.firstName });
    // D47: only a consequence the policy states is worded. The published policy has no "counts as missed" field, so
    // the line says what is certain (the free period ended, the professional is told) and nothing more.
    return policy.lateCancelCounts === true ? t('bk9.cancel.lateCounts', { name: pro.firstName }) : t('bk9.cancel.late', { name: pro.firstName });
  })();

  const row = (title: string, sub: string | null, content: { to: Route | string } | { href: string | null } | { onClick: () => void }, options: { danger?: boolean; testId: string }): JSX.Element => {
    const inner = (
      <>
        <span class="grow">
          <b>{title}</b>
          {sub === null ? null : <span class="sub">{sub}</span>}
        </span>
        <Icon name="chevron" class="icon-quiet" />
      </>
    );
    const klass = `list-row${options.danger === true ? ' row-danger' : ''}`;
    if ('to' in content) return <Link to={content.to} class={klass} testId={options.testId}>{inner}</Link>;
    if ('href' in content) {
      return content.href === null ? (
        <span class={klass}>{inner}</span>
      ) : (
        <ExternalLink href={content.href} class={klass} testId={options.testId}>
          {inner}
        </ExternalLink>
      );
    }
    return <button type="button" class={klass} onClick={content.onClick} data-testid={options.testId}>{inner}</button>;
  };

  return (
    <Screen top={<TopBar back={slugRoute(pro.slug)} backLabel={t('bk11.page', { name: pro.displayName })} />}>
      <div class="stack-sm">
        <Title>{t('bk9.title')}</Title>
        <div>
          <StatusChip kind={status.kind}>
            <span data-testid="status">{t(status.key)}</span>
          </StatusChip>
        </div>
      </div>

      {((request) =>
        request === undefined ? null : (
          <Notice kind="warning" icon="clock" testId="asked-move">
            {t('bk9.askedMove', { when: `${format.weekdayDate(request.requestedStart)} · ${format.time(request.requestedStart)}`, name: pro.firstName })}
          </Notice>
        ))(openRequest(booking))}

      <section class="card" aria-label={t('bk8.summary')} data-testid="booking-card">
        <p class="meta strong">{format.weekdayDate(startsAt)}</p>
        <p class="moment tn" data-testid="start-time">{format.time(startsAt)}</p>
        <p class="meta tn">{t('bk9.zone', { end: format.time(endsAt), place })}</p>
        <hr class="rule" />
        <b class="strong section">
          <bdi>{[booking.service.name, ...booking.addOns.map((addOn) => addOn.name)].join(' + ')}</bdi>
        </b>
        <p class="meta">
          {t('bk9.with', { name: pro.displayName, meta: format.minutes(booking.durationMinutes) })}
        </p>
        {booking.guestCount > 0 ? <p class="meta">{t('bk8.guest.unnamed', { count: booking.guestCount })}</p> : null}
      </section>

      {active ? (
        <section class="stack-sm" aria-labelledby="change-title" data-testid="change-or-cancel">
          <h2 id="change-title" class="strong">
            {t('bk9.changeOrCancel')}
          </h2>
          <ul class="card card-flush list" data-testid="actions">
            {booking.status === 'confirmed' ? (
              <li>
                {row(
                  t('bk9.reschedule'),
                  resSub,
                  resched === 'direct' || resched === 'request' ? { to: manageRoute(token, 'reschedule') } : { href: message('wa.reschedule') },
                  { testId: 'reschedule' },
                )}
              </li>
            ) : null}
            <li>
              {row(t('bk9.cancel'), cancelSub, cancel === 'free' || cancel === 'allowedWithWarning' ? { to: manageRoute(token, 'cancel') } : { href: message('wa.cancel') }, { danger: true, testId: 'cancel' })}
            </li>
          </ul>
          <Notice kind={cancel === 'free' ? 'quiet' : 'warning'} testId="policy-note">
            {cancel === 'free' ? t('bk9.note.free', { deadline }) : t('bk9.note.late', { deadline })}
          </Notice>
        </section>
      ) : null}

      {booking.location === undefined || gone ? null : <PlaceCard location={booking.location} />}

      {booking.status === 'pendingApproval' ? (
        <Notice kind="warning" icon="clock" title={t('bk10.title', { name: pro.firstName })} testId="pending">
          {t('bk9.pending.text', { name: pro.firstName })}
        </Notice>
      ) : null}

      {showAttend && attend === null ? (
        <section class="card stack-sm" aria-labelledby="attend-title" data-testid="attend">
          <h2 id="attend-title" class="strong">{t('bk9.attend.title')}</h2>
          <p class="meta">{t('bk9.attend.text', { name: pro.firstName })}</p>
          <div class="stack-sm">
            <TextField
              label={t('bk5.email')}
              type="email"
              inputMode="email"
              autoComplete="email"
              value={email}
              optional
              error={fieldErrors.email}
              testId="attend-email"
              onInput={(v) => {
                setEmail(v);
                setFieldErrors((prev) => ({ ...prev, email: undefined }));
              }}
            />
            <TextField
              label={t('bk9.attend.confirmEmail')}
              type="email"
              inputMode="email"
              autoComplete="email"
              value={confirmEmail}
              optional
              error={fieldErrors.confirmEmail}
              testId="attend-confirm-email"
              onInput={(v) => {
                setConfirmEmail(v);
                setFieldErrors((prev) => ({ ...prev, confirmEmail: undefined }));
              }}
            />
            <PhoneField
              label={t('bk5.phone')}
              countryLabel={t('bk5.phoneCountry')}
              country={phoneCountry}
              input={phone}
              defaultCountry={pro.regionCode}
              error={fieldErrors.phone}
              testId="attend-phone"
              onChange={(c, p) => {
                setPhoneCountry(c);
                setPhone(p);
                setFieldErrors((prev) => ({ ...prev, phone: undefined }));
              }}
            />
            <TextField
              label={t('bk9.attend.confirmPhone')}
              type="tel"
              inputMode="tel"
              value={confirmPhone}
              optional
              error={fieldErrors.confirmPhone}
              testId="attend-confirm-phone"
              onInput={(v) => {
                setConfirmPhone(v);
                setFieldErrors((prev) => ({ ...prev, confirmPhone: undefined }));
              }}
            />
          </div>
          <div class="row-flex">
            <Button inline busy={busy} onClick={() => { void confirmPresence(); }} testId="attend-yes">{t('bk9.attend.yes')}</Button>
            <Button inline variant="secondary" onClick={() => { setAttend('no'); }} testId="attend-no">{t('bk9.attend.no')}</Button>
          </div>
        </section>
      ) : null}
      {attend === 'yes' ? (
        <Notice kind="info" icon="check" live="polite" title={t('bk9.attend.thanks')} testId="attend-thanks">
          {t('bk9.attend.thanksText', { name: pro.firstName })}
        </Notice>
      ) : null}
      {attend === 'no' ? (
        <Notice kind="quiet" icon="info" live="polite" title={t('bk9.attend.noTitle')} testId="attend-no-text">
          {t('bk9.attend.noText', { name: pro.firstName })}
        </Notice>
      ) : null}

      {showLate ? (
        <section class="card stack-sm" aria-labelledby="late-title" data-testid="late">
          <h2 id="late-title" class="strong">{late === null ? t('bk9.late.title') : t('bk9.late.knows', { name: pro.firstName })}</h2>
          <p class="meta" aria-live="polite">
            {late === null
              ? t('bk9.late.text', { name: pro.firstName, minutes: format.minutes(policy.graceMinutes) })
              : late <= policy.graceMinutes
                ? t('bk9.late.held', { minutes: format.minutes(late), time: format.time(startsAt) })
                : t('bk9.late.over', { grace: format.minutes(policy.graceMinutes) })}
          </p>
          <div class="chips" role="group" aria-label={t('bk9.late.title')}>
            {LATE_MINUTES.map((minutes) => (
              <Chip key={minutes} pressed={late === minutes} testId={`late-${minutes}`} onToggle={() => { void reportLate(minutes); }}>
                {format.minutes(minutes)}
              </Chip>
            ))}
          </div>
        </section>
      ) : null}

      <ErrorNotice error={failure} />

      {gone ? (
        <section class="card stack-sm" data-testid="cancelled">
          <h2 class="strong">{booking.status === 'declined' ? t('bk9.declinedTitle') : t('bk9.cancelledTitle')}</h2>
          <p class="meta">{booking.status === 'cancelledByClient' ? t('bk9.cancelledText', { name: pro.firstName }) : t('bk9.cancelledByProText', { name: pro.firstName })}</p>
          <Link to={manageRoute(token, 'rebook')} class="btn btn-primary" testId="book-again">
            {t('bk9.bookAgain')}
          </Link>
        </section>
      ) : null}

      {active ? (
        <ul class="card card-flush list" data-testid="calendar-actions">
          <li>{row(t('cal.add'), null, { onClick: () => { setCalendarOpen(true); } }, { testId: 'add-calendar' })}</li>
        </ul>
      ) : null}

      {isCompleted(booking) ? (
        <Link to={manageRoute(token, 'checkin')} class="card list-row" testId="checkin-link">
          <span class="grow">
            <b class="strong">{t('bk9.checkin.title')}</b>
            <span class="sub">{t('bk9.checkin.text', { name: pro.firstName })}</span>
          </span>
          <Icon name="chevron" class="icon-quiet" />
        </Link>
      ) : null}

      {active && booking.intakeRequired ? (
        <Link to={manageRoute(token, 'form')} class="card list-row" testId="health-form">
          <span class="grow">
            <b class="strong">{t('bk8.form.title')}</b>
            <span class="sub">{t('bk8.form.text', { name: pro.firstName })}</span>
          </span>
          <Icon name="chevron" class="icon-quiet" />
        </Link>
      ) : null}

      {active ? <BookingRules policy={policy} professionalFirstName={pro.firstName} /> : null}

      {(() => {
        const url = message('wa.hello');
        return url === null ? null : (
          <ExternalLink href={url} class="card list-row" testId="message-pro">
            <Avatar name={pro.displayName} photo={pro.photo} />
            <span class="grow">
              <b class="strong">{t('bk9.questions', { name: pro.firstName })}</b>
              <span class="sub">{t('bk9.messageWa')}</span>
            </span>
            <Icon name="chevron" class="icon-quiet" />
          </ExternalLink>
        );
      })()}

      <p class="center">
        <Link to={manageRoute(token, 'data')} class="link-button" testId="my-data">
          {t('bk9.myData')}
        </Link>
      </p>
      <ForgetDevice slug={booking.slug} />
      <Footer />
      <CalendarSheet
        open={calendarOpen}
        onClose={() => { setCalendarOpen(false); }}
        booking={{ bookingId: booking.bookingId, startsAt: booking.startsAt, endsAt: booking.endsAt, serviceNames: [booking.service.name, ...booking.addOns.map((addOn) => addOn.name)], professional: { displayName: pro.displayName, city: pro.city }, place: booking.location }}
        pageUrl={pageUrl(pro.slug)}
      />
    </Screen>
  );
}

/**
 * "Forget this device" (API.md 5.18): shown only when this browser keeps a trusted-device token for her page. The token
 * is dropped here at once and on the server as well as the network allows; either way the next booking asks for a code.
 */
function ForgetDevice({ slug }: { slug: string }): JSX.Element | null {
  const { t } = useI18n();
  const [stored] = useState(() => storedDeviceToken(slug));
  const [forgotten, setForgotten] = useState(false);
  if (stored === null) return null;
  if (forgotten) {
    return (
      <Notice kind="quiet" icon="check" live="polite" testId="device-forgotten">
        {t('bk9.device.forgotten')}
      </Notice>
    );
  }
  return (
    <p class="center stack-sm" data-testid="forget-device-row">
      <span class="meta">{t('bk9.device.text')}</span>
      <button
        type="button"
        class="link-button"
        data-testid="forget-device"
        onClick={() => {
          forgetDeviceLocally(slug);
          setForgotten(true);
          api.forgetDevice(stored).catch(() => undefined);
        }}
      >
        {t('bk9.device.forget')}
      </button>
    </p>
  );
}
