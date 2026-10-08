// Cl-3: book again. Opened from the portal (/p/{token}/rebook), from a finished or cancelled appointment
// (/m/{token}/rebook) or from the reminder: her details are saved, she only chooses a time (docs/10 section 3,
// "Return visits"). The server decides the outcome like any booking: confirmed, waiting for approval, or paused.

import type { JSX } from 'preact';
import { useEffect, useMemo, useState } from 'preact/hooks';

import { api } from '../../api/client';
import { ApiError } from '../../api/errors';
import type { BookingResult, ProfessionalLite } from '../../api/types';
import { TokenLayout } from '../../app/TokenLayout';
import { useFormatter } from '../../app/context';
import { manageRoute, routePath, type Route } from '../../app/router';
import { groupByDay } from '../booking/TimeStep';
import { Button, ExternalLink, LinkButton } from '../../components/Button';
import { DayStrip, SlotList } from '../../components/Calendar';
import { ErrorNotice, Notice, Seal } from '../../components/Feedback';
import { Avatar, Footer, Screen, Title, TopBar, useDocumentTitle } from '../../components/Layout';
import { useI18n } from '../../i18n';
import type { DateKey } from '../../lib/datetime';
import { zonedDateKey } from '../../lib/datetime';
import { whatsAppUrl } from '../../lib/whatsapp';

interface RebookInfo {
  readonly professional: ProfessionalLite;
  readonly firstName: string | undefined;
  readonly service: { readonly name: string; readonly durationMinutes: number };
  readonly recommendedDate: string | undefined;
  readonly mode: 'direct' | 'approval' | 'paused';
  readonly back: Route | string;
}

const DAYS_AHEAD = 35;
const DAY_CHOICES = 12;

export function RebookPage({ token, kind }: { token: string; kind: 'manage' | 'portal' }): JSX.Element {
  return (
    <TokenLayout
      load={async (): Promise<RebookInfo> => {
        if (kind === 'portal') {
          const portal = await api.getPortal(token);
          if (portal.next === undefined) throw new ApiError('notFound');
          return {
            professional: portal.professional,
            firstName: portal.client.firstName,
            service: { name: portal.next.serviceName, durationMinutes: portal.next.durationMinutes },
            recommendedDate: portal.next.recommendedDate,
            mode: portal.rebookMode,
            back: `/p/${token}`,
          };
        }
        const booking = await api.getBooking(token);
        return {
          professional: booking.professional,
          firstName: booking.client?.firstName,
          service: { name: booking.service.name, durationMinutes: booking.service.durationMinutes },
          recommendedDate: undefined,
          mode: 'direct',
          back: manageRoute(token),
        };
      }}
      deps={[token, kind]}
      professionalOf={(info) => info.professional}
    >
      {(info) => <Rebook token={token} info={info} />}
    </TokenLayout>
  );
}

type Load = { status: 'loading' } | { status: 'ready'; byDay: ReadonlyMap<DateKey, readonly string[]> } | { status: 'error'; error: unknown };

function Rebook({ token, info }: { token: string; info: RebookInfo }): JSX.Element {
  const { t } = useI18n();
  const format = useFormatter();
  const pro = info.professional;
  useDocumentTitle(info.firstName === undefined ? t('cl3.titleAnon') : t('cl3.title', { name: info.firstName }));

  const [load, setLoad] = useState<Load>({ status: 'loading' });
  const [attempt, setAttempt] = useState(0);
  const [day, setDay] = useState<DateKey | null>(null);
  const [pick, setPick] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);
  const [result, setResult] = useState<BookingResult | null>(null);

  useEffect(() => {
    if (info.mode === 'paused') return;
    let current = true;
    setLoad({ status: 'loading' });
    const from = Date.now();
    api
      .getSlots({ token, purpose: 'rebook', from: new Date(from).toISOString(), to: new Date(from + DAYS_AHEAD * 24 * 3_600_000).toISOString() })
      .then(
        (response) => {
          if (!current) return;
          const byDay = groupByDay(response.slots, pro.timeZoneID);
          setLoad({ status: 'ready', byDay });
          const preferred = info.recommendedDate === undefined ? undefined : zonedDateKey(Date.parse(info.recommendedDate), pro.timeZoneID);
          const first = [...byDay.keys()].sort()[0];
          setDay((existing) => existing ?? (preferred !== undefined && byDay.has(preferred) ? preferred : (first ?? null)));
        },
        (error: unknown) => {
          if (current) setLoad({ status: 'error', error });
        },
      );
    return () => {
      current = false;
    };
  }, [token, attempt, info.mode]);

  const byDay = load.status === 'ready' ? load.byDay : new Map<DateKey, readonly string[]>();
  const best = info.recommendedDate === undefined ? undefined : zonedDateKey(Date.parse(info.recommendedDate), pro.timeZoneID);
  const days = useMemo(() => [...byDay.keys()].sort().slice(0, DAY_CHOICES).map((key) => ({ key, best: key === best })), [byDay, best]);
  const slots = day === null ? [] : (byDay.get(day) ?? []);
  const message = whatsAppUrl(pro.whatsappE164, t('wa.book', { name: pro.firstName }));

  const submit = async (): Promise<void> => {
    if (pick === null) return;
    setBusy(true);
    setFailure(null);
    try {
      const response = await api.rebook({ token, startsAt: pick });
      if (response.status === 'slotTaken') {
        setPick(null);
        setAttempt((value) => value + 1);
        setFailure(new ApiError('slotTaken'));
      } else {
        setResult(response);
      }
    } catch (error) {
      setFailure(error);
    } finally {
      setBusy(false);
    }
  };

  if (result !== null && result.status === 'confirmed') {
    return (
      <Screen>
        <div class="stack">
          <Seal />
          <Title>{info.firstName === undefined ? t('cl3.doneTitleAnon') : t('cl3.doneTitle', { name: info.firstName })}</Title>
          <p class="lead" data-testid="done-text">{t('cl3.doneText', { service: info.service.name })}</p>
        </div>
        <section class="card" data-testid="done-card">
          <b class="strong section"><bdi>{info.service.name}</bdi></b>
          <p class="meta">{t('bk9.with', { name: pro.displayName, meta: format.minutes(result.booking.totalMinutes) })}</p>
          <hr class="rule" />
          <b class="strong">{format.weekdayDate(result.booking.startsAt)}</b>
          <p class="moment tn">{format.time(result.booking.startsAt)}</p>
        </section>
        <LinkButton to={routePath(manageRoute(result.manageToken))} testId="view-appointment">{t('bk8.view')}</LinkButton>
        <Footer />
      </Screen>
    );
  }
  if (result !== null) {
    const sent = result.status === 'pendingApproval';
    return (
      <Screen>
        <div class="stack">
          <Seal tone="amber" />
          <Title>{sent ? t('cl3.sentTitle') : t('bk10.blocked.title')}</Title>
          <p class="lead" data-testid="done-text">{sent ? t('cl3.sentText', { name: pro.firstName, service: info.service.name }) : t('cl3.pausedGate', { name: pro.firstName })}</p>
        </div>
        <LinkButton to={info.back} variant="secondary">{t('cl3.back')}</LinkButton>
        <Footer />
      </Screen>
    );
  }

  const when = pick === null ? '' : `${format.shortDate(pick)} · ${format.time(pick)}`;
  const bar =
    info.mode === 'paused' ? (
      message === null ? undefined : (
        <ExternalLink href={message} variant="primary" testId="message-pro">
          {t('bk1.messageWa', { name: pro.firstName })}
        </ExternalLink>
      )
    ) : (
      <Button busy={busy} disabled={pick === null} onClick={() => { void submit(); }} testId="rebook">
        {pick === null ? t('cl3.pickFirst') : info.mode === 'approval' ? t('cl3.ask', { name: pro.firstName, when }) : t('cl3.rebook', { when })}
      </Button>
    );

  return (
    <Screen top={<TopBar back={info.back} backLabel={t('cl3.back')} />} bar={bar}>
      <div>
        <Title>{info.firstName === undefined ? t('cl3.titleAnon') : t('cl3.title', { name: info.firstName })}</Title>
        <p class="lead">{t('cl3.sub')}</p>
      </div>

      {info.mode === 'direct' ? null : (
        <Notice kind="warning" icon="info" testId="gate">
          {info.mode === 'paused' ? t('cl3.pausedGate', { name: pro.firstName }) : t('cl3.approvalGate', { name: pro.firstName })}
        </Notice>
      )}

      <section class="card row-flex">
        <Avatar name={pro.displayName} photo={pro.photo} />
        <div>
          <b class="strong"><bdi>{info.service.name}</bdi></b>
          <br />
          <span class="meta">{t('bk9.with', { name: pro.displayName, meta: format.minutes(info.service.durationMinutes) })}</span>
        </div>
      </section>

      {info.mode === 'paused' ? null : load.status === 'error' ? (
        <div class="stack">
          <ErrorNotice error={load.error} />
          <Button variant="secondary" inline onClick={() => { setAttempt((value) => value + 1); }}>{t('common.retry')}</Button>
        </div>
      ) : load.status === 'loading' ? (
        <div class="skeleton skeleton-block" aria-busy="true" />
      ) : days.length === 0 ? (
        <p class="lead" data-testid="no-times">{t('cl9.noTimes', { name: pro.firstName })}</p>
      ) : (
        <>
          <div class="stack-sm">
            <h2 class="section">{t('cl3.day')}</h2>
            <DayStrip days={days} selected={day} formatter={format} onSelect={(key) => { setDay(key); setPick(null); }} label={t('cl3.day')} bestLabel={t('cl3.best')} />
            {best === undefined ? null : <p class="foot-note">{t('cl3.bestNote', { name: pro.firstName })}</p>}
          </div>
          <div class="stack-sm">
            <h2 class="section">{t('cl3.time')}</h2>
            <SlotList slots={slots} selected={pick} formatter={format} onSelect={setPick} label={t('cl3.time')} />
          </div>
        </>
      )}
      <ErrorNotice error={failure} />
    </Screen>
  );
}
