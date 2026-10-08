// Cl-6: cancel (docs/10 section 4, D11, D12). Inside the free window it is immediate and costs nothing. After it she
// can still cancel, with an honest warning when it counts as a missed appointment, or she is asked to message the
// professional, depending on her policy as it was when she booked. The reason is optional and sent as a key.

import type { JSX } from 'preact';
import { useEffect, useState } from 'preact/hooks';

import { api } from '../../api/client';
import type { BookingView } from '../../api/types';
import { useFormatter } from '../../app/context';
import { manageRoute, navigate } from '../../app/router';
import { Button, ExternalLink, LinkButton } from '../../components/Button';
import { Chip } from '../../components/Choices';
import { ErrorNotice, Notice, Seal } from '../../components/Feedback';
import { Footer, Screen, Title, TopBar, useDocumentTitle } from '../../components/Layout';
import { useI18n } from '../../i18n';
import { cancelMode, freeUntil, lateCancelCountsAgainst, rescheduleMode } from '../../lib/policy';
import { whatsAppUrl } from '../../lib/whatsapp';
import { serverClock } from './ManagePage';

const REASONS = [
  { value: 'conflict', key: 'cl6.reason.conflict' },
  { value: 'unwell', key: 'cl6.reason.unwell' },
  { value: 'changed', key: 'cl6.reason.changed' },
  { value: 'other', key: 'cl6.reason.other' },
] as const;

export function CancelPage({ token, booking }: { token: string; booking: BookingView }): JSX.Element | null {
  const { t } = useI18n();
  const format = useFormatter();
  const pro = booking.professional;
  const now = serverClock(booking)();
  const startsAt = Date.parse(booking.startsAt);
  const policy = booking.policy;
  const mode = cancelMode(startsAt, policy, now);
  const resched = rescheduleMode(startsAt, policy, now, booking.rescheduleCount);
  const counts = lateCancelCountsAgainst(mode, policy);
  const cancellable = booking.status === 'confirmed' || booking.status === 'pendingApproval';
  const [reason, setReason] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);
  const [done, setDone] = useState<{ counted: boolean } | null>(null);
  useDocumentTitle(mode === 'free' ? t('cl6.title.free') : mode === 'allowLate' ? t('cl6.title.late') : t('cl6.title.message', { name: pro.firstName }));

  useEffect(() => {
    if (!cancellable && done === null) navigate(manageRoute(token), true);
  }, [cancellable, token, done]);
  if (!cancellable && done === null) return null;

  const deadline = `${format.shortDate(freeUntil(startsAt, policy))} · ${format.time(freeUntil(startsAt, policy))}`;

  const cancel = async (): Promise<void> => {
    setBusy(true);
    setFailure(null);
    try {
      const response = await api.cancelBooking({ token, ...(reason === null ? {} : { reason }) });
      setDone({ counted: response.countedAsLate });
    } catch (error) {
      setFailure(error);
    } finally {
      setBusy(false);
    }
  };

  if (done !== null) {
    const late = mode !== 'free';
    return (
      <Screen>
        <div class="stack">
          <Seal />
          <Title>{late ? t('cl6.done.late', { name: pro.firstName }) : t('cl6.done.free')}</Title>
          <p class="lead" data-testid="done-text">
            {late ? t('cl6.doneText.late') : t('cl6.doneText.free', { name: pro.firstName })}
            {done.counted ? ` ${t('cl6.doneText.counts')}` : ''}
          </p>
        </div>
        <LinkButton to={manageRoute(token, 'rebook')} testId="book-again">
          {t('cl6.bookAgain')}
        </LinkButton>
        <Footer />
      </Screen>
    );
  }

  const message = whatsAppUrl(pro.whatsappE164, t('wa.cancel', { name: pro.firstName, service: booking.service.name, date: format.dayMonth(startsAt), time: format.time(startsAt) }));
  const askMessage = whatsAppUrl(pro.whatsappE164, t('wa.reschedule', { name: pro.firstName, service: booking.service.name, date: format.dayMonth(startsAt), time: format.time(startsAt) }));
  const top = <TopBar back={manageRoute(token)} backLabel={t('cl9.back')} />;

  if (mode === 'message') {
    return (
      <Screen top={top} bar={message === null ? undefined : <ExternalLink href={message} variant="primary" testId="message-pro">{t('bk1.messageWa', { name: pro.firstName })}</ExternalLink>}>
        <div class="stack">
          <Title>{t('cl6.title.message', { name: pro.firstName })}</Title>
          <p class="lead">{t('cl6.sub.message', { name: pro.firstName, deadline })}</p>
        </div>
      </Screen>
    );
  }

  const bar = (
    <>
      {resched === 'direct' ? (
        <LinkButton to={manageRoute(token, 'reschedule')} testId="reschedule-instead">
          {t('cl6.rescheduleInstead')}
        </LinkButton>
      ) : resched === 'request' ? (
        <LinkButton to={manageRoute(token, 'reschedule')} testId="reschedule-instead">
          {t('cl6.askInstead')}
        </LinkButton>
      ) : askMessage === null ? null : (
        <ExternalLink href={askMessage} variant="secondary" testId="message-resched">
          {t('cl6.messageResched', { name: pro.firstName })}
        </ExternalLink>
      )}
      <Button variant="secondary" busy={busy} onClick={() => { void cancel(); }} testId="confirm-cancel">
        {mode === 'free' ? t('cl6.confirm.free') : t('cl6.confirm.late')}
      </Button>
    </>
  );

  return (
    <Screen top={top} bar={bar}>
      <div>
        <Title>{mode === 'free' ? t('cl6.title.free') : t('cl6.title.late')}</Title>
        <p class="lead">{mode === 'free' ? t('cl6.sub.free', { deadline }) : t('cl6.sub.late', { name: pro.firstName, deadline })}</p>
      </div>

      {counts ? (
        <Notice kind="warning" icon="alert" title={t('cl6.warn.title')} testId="counts-warning">
          {t('cl6.warn.text', { name: pro.firstName, count: policy.noShowLimit ?? 3 })}
          {resched === 'message' ? '' : ` ${t('cl6.warn.instead')}`}
        </Notice>
      ) : null}

      <section class="card" aria-label={t('bk8.summary')}>
        <b class="strong section">
          <bdi>{booking.service.name}</bdi>
        </b>
        <p class="meta">{format.minutes(booking.totalMinutes)}</p>
        <p class="meta tn">{`${format.weekdayDate(startsAt)} · ${format.time(startsAt)}`}</p>
      </section>

      <fieldset class="stack-sm">
        <legend class="section">{t('cl6.why')}</legend>
        <div class="chips mt-sm" role="group" aria-label={t('cl6.why')}>
          {REASONS.map((option) => (
            <Chip key={option.value} pressed={reason === option.value} testId={`reason-${option.value}`} onToggle={() => { setReason(reason === option.value ? null : option.value); }}>
              {t(option.key)}
            </Chip>
          ))}
        </div>
        <p class="foot-note">{t('cl6.whyHint', { name: pro.firstName })}</p>
      </fieldset>

      <ErrorNotice error={failure} />
    </Screen>
  );
}
