// Cl-9: reschedule (docs/10 section 4, API.md 5.12). Three modes, the server's verdict on her policy as it was when
// she booked: pick a new time and it moves at once (inside the free window), ask for one and the old time stays
// hers until the professional answers (after it), or message her (when changes are closed or the limit is reached).

import type { JSX } from 'preact';
import { useEffect, useMemo, useState } from 'preact/hooks';

import { api } from '../../api/client';
import { ApiError } from '../../api/errors';
import type { BookingView } from '../../api/types';
import { useFormatter } from '../../app/context';
import { manageRoute, navigate } from '../../app/router';
import { groupByDay } from '../../app/booking/slotDays';
import { Button, ExternalLink, LinkButton } from '../../components/Button';
import { SlotList, DayStrip } from '../../components/Calendar';
import { ErrorNotice, Notice, Seal } from '../../components/Feedback';
import { TextField } from '../../components/Field';
import { Icon } from '../../components/Icon';
import { Footer, Screen, Title, TopBar, useDocumentTitle } from '../../components/Layout';
import { useI18n } from '../../i18n';
import { addDays, zonedDateKey, type DateKey } from '../../lib/datetime';
import { freeUntil, reschedulesLeft } from '../../lib/policy';
import { whatsAppUrl } from '../../lib/whatsapp';

const DAYS_AHEAD = 28;
const DAY_CHOICES = 10;

type Load = { status: 'loading' } | { status: 'ready'; byDay: ReadonlyMap<DateKey, readonly string[]> } | { status: 'error'; error: unknown };

export function ReschedulePage({ token, booking }: { token: string; booking: BookingView }): JSX.Element | null {
  const { t } = useI18n();
  const format = useFormatter();
  const pro = booking.professional;
  const startsAt = Date.parse(booking.startsAt);
  const verdict = booking.actions.reschedule;
  const mode = verdict === 'direct' || verdict === 'request' ? verdict : 'message';
  const left = reschedulesLeft(booking.policy, booking.rescheduleCount);
  const editable = booking.status === 'confirmed' && verdict !== 'unavailable';
  useDocumentTitle(mode === 'request' ? t('cl9.title.ask') : mode === 'direct' ? t('cl9.title.self') : t('cl9.title.msg', { name: pro.firstName }));

  useEffect(() => {
    if (!editable) navigate(manageRoute(token), true);
  }, [editable, token]);

  const [load, setLoad] = useState<Load>({ status: 'loading' });
  const [attempt, setAttempt] = useState(0);
  const [day, setDay] = useState<DateKey | null>(null);
  const [pick, setPick] = useState<string | null>(null);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);
  const [done, setDone] = useState<{ kind: 'moved' | 'asked'; at: string } | null>(null);

  useEffect(() => {
    if (!editable || mode === 'message') return;
    let current = true;
    setLoad({ status: 'loading' });
    const from = zonedDateKey(Date.now(), pro.timeZoneID);
    api
      .getSlots({ slug: pro.slug, serviceId: booking.service.id, from, to: addDays(from, DAYS_AHEAD), rescheduleToken: token })
      .then(
        (response) => {
          if (!current) return;
          const byDay = groupByDay(response.slots, pro.timeZoneID);
          setLoad({ status: 'ready', byDay });
          const first = [...byDay.keys()].sort()[0];
          setDay((existing) => (existing !== null && byDay.has(existing) ? existing : (first ?? null)));
        },
        (error: unknown) => {
          if (current) setLoad({ status: 'error', error });
        },
      );
    return () => {
      current = false;
    };
  }, [token, attempt, mode, editable]);

  const byDay = load.status === 'ready' ? load.byDay : new Map<DateKey, readonly string[]>();
  const days = useMemo(() => [...byDay.keys()].sort().slice(0, DAY_CHOICES).map((key) => ({ key })), [byDay]);
  const slots = day === null ? [] : (byDay.get(day) ?? []);

  if (!editable) return null;

  const confirm = async (): Promise<void> => {
    if (pick === null) return;
    setBusy(true);
    setFailure(null);
    try {
      if (mode === 'direct') await api.rescheduleBooking({ token, startsAt: pick });
      else await api.requestReschedule({ token, startsAt: pick, ...(note.trim() === '' ? {} : { note: note.trim() }) });
      setDone({ kind: mode === 'direct' ? 'moved' : 'asked', at: pick });
    } catch (error) {
      if (error instanceof ApiError && error.code === 'slotTaken') {
        setPick(null);
        setAttempt((value) => value + 1);
      }
      setFailure(error);
    } finally {
      setBusy(false);
    }
  };

  if (done !== null) {
    return (
      <Screen>
        <div class="stack">
          <Seal tone={done.kind === 'asked' ? 'amber' : 'sage'} />
          <Title>{done.kind === 'asked' ? t('cl9.doneAsked') : t('cl9.doneMoved')}</Title>
          <p class="lead" data-testid="done-text">
            {done.kind === 'asked'
              ? t('cl9.doneAskedText', { name: pro.firstName, when: `${format.weekdayDate(startsAt)} · ${format.time(startsAt)}` })
              : t('cl9.doneMovedText', { name: pro.firstName })}
          </p>
        </div>
        <section class="card" data-testid="new-time">
          <p class="meta">{done.kind === 'asked' ? t('cl9.youAsked') : t('cl9.newTime')}</p>
          <b class="strong tn">{`${format.weekdayDate(done.at)} · ${format.time(done.at)}`}</b>
        </section>
        <LinkButton to={manageRoute(token)} testId="back-to-appointment">
          {t('cl9.back2')}
        </LinkButton>
        <Footer />
      </Screen>
    );
  }

  const message = whatsAppUrl(pro.whatsappE164, t('wa.reschedule', { name: pro.firstName, service: booking.service.name, date: format.dayMonth(startsAt), time: format.time(startsAt) }));
  const current = `${format.weekdayDate(startsAt)} · ${format.time(startsAt)}`;
  const backTop = <TopBar back={manageRoute(token)} backLabel={t('cl9.back')} />;

  if (mode === 'message') {
    const why = !booking.policy.clientCanReschedule ? t('cl9.msg.noSelf', { name: pro.firstName }) : left === 0 ? t('cl9.msg.limit', { name: pro.firstName }) : t('cl9.msg.ended', { name: pro.firstName, deadline: `${format.shortDate(freeUntil(startsAt, booking.policy))} · ${format.time(freeUntil(startsAt, booking.policy))}` });
    return (
      <Screen top={backTop} bar={message === null ? undefined : <ExternalLink href={message} variant="primary" testId="message-pro">{t('bk1.messageWa', { name: pro.firstName })}</ExternalLink>}>
        <div class="stack">
          <Title>{t('cl9.title.msg', { name: pro.firstName })}</Title>
        </div>
        <section class="card stack-sm">
          <h2 class="strong">{t('cl9.msg.title', { name: pro.firstName })}</h2>
          <p class="meta" data-testid="why">{why}</p>
        </section>
      </Screen>
    );
  }

  const cta = mode === 'direct' ? t('cl9.cta.self', { when: pick === null ? '' : `${format.shortDate(pick)} · ${format.time(pick)}` }) : t('cl9.cta.ask', { when: pick === null ? '' : `${format.shortDate(pick)} · ${format.time(pick)}` });
  return (
    <Screen
      top={backTop}
      bar={
        <Button busy={busy} disabled={pick === null} onClick={() => { void confirm(); }} testId="confirm-reschedule">
          {pick === null ? t('cl9.pickFirst') : cta.trim()}
        </Button>
      }
    >
      <div>
        <Title>{mode === 'direct' ? t('cl9.title.self') : t('cl9.title.ask')}</Title>
        <p class="lead">
          {mode === 'direct'
            ? t('cl9.sub.self', { deadline: `${format.shortDate(freeUntil(startsAt, booking.policy))} · ${format.time(freeUntil(startsAt, booking.policy))}` })
            : t('cl9.sub.ask', { name: pro.firstName })}
        </p>
      </div>

      <div class="card row-flex">
        <Icon name="calendar" />
        <div>
          <span class="meta">{t('cl9.current')}</span>
          <br />
          <b class="strong tn" data-testid="current-time">{current}</b>
        </div>
      </div>

      {load.status === 'error' ? (
        <div class="stack">
          <ErrorNotice error={load.error} />
          <Button variant="secondary" inline onClick={() => { setAttempt((value) => value + 1); }}>
            {t('common.retry')}
          </Button>
        </div>
      ) : load.status === 'loading' ? (
        <div class="skeleton skeleton-block" aria-busy="true" />
      ) : days.length === 0 ? (
        <p class="lead" data-testid="no-times">{t('cl9.noTimes', { name: pro.firstName })}</p>
      ) : (
        <>
          <div class="stack-sm">
            <h2 class="section">{t('cl9.day')}</h2>
            <DayStrip days={days} selected={day} formatter={format} onSelect={(key) => { setDay(key); setPick(null); }} label={t('cl9.day')} bestLabel="" />
          </div>
          <div class="stack-sm">
            <h2 class="section">{t('cl9.time')}</h2>
            <SlotList slots={slots} selected={pick} formatter={format} onSelect={setPick} label={t('cl9.time')} />
          </div>
        </>
      )}

      {mode === 'request' ? <TextField label={t('cl9.note', { name: pro.firstName })} optional value={note} onInput={setNote} placeholder={t('cl9.notePlaceholder')} sensitive testId="note" /> : null}

      <Notice kind="quiet" icon="info">
        {mode === 'request' ? t('cl9.hold.ask', { name: pro.firstName }) : t('cl9.hold.self')}
        {left === null ? '' : ` ${t('cl9.changeOf', { current: booking.rescheduleCount + 1, max: booking.policy.maxReschedules ?? 0 })}`}
      </Notice>
      <ErrorNotice error={failure} />
    </Screen>
  );
}
