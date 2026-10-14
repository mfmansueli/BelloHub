// Cl-3: book again. Opened from the portal (/p/{token}/rebook) or from a finished or cancelled appointment
// (/m/{token}/rebook): her details are saved, she only chooses a time (docs/10 section 3, "Return visits"). The
// server decides the outcome like any booking (API.md 5.13): confirmed, waiting for approval, or paused; the page
// does not know beforehand and never pretends to.

import type { JSX } from 'preact';
import { useEffect, useMemo, useState } from 'preact/hooks';

import { api } from '../../api/client';
import { ApiError } from '../../api/errors';
import type { BookingOutcome, ProfessionalLite } from '../../api/types';
import { TokenLayout } from '../../app/TokenLayout';
import { useFormatter } from '../../app/context';
import { newIdempotencyKey } from '../../app/booking/machine';
import { currentRebookMinutes, rebookOfferState, type RebookOfferState } from '../../app/booking/rebookOffer';
import { loadPublicPage } from '../../app/pageData';
import { manageRoute, routePath, type Route } from '../../app/router';
import { groupByDay } from '../../app/booking/slotDays';
import { Button, ExternalLink, LinkButton } from '../../components/Button';
import { DayStrip } from '../../components/Calendar';
import { SlotChoices } from '../../components/SlotChoices';
import { ErrorNotice, Notice, Seal } from '../../components/Feedback';
import { Avatar, Footer, Screen, Title, TopBar, useDocumentTitle } from '../../components/Layout';
import { useI18n } from '../../i18n';
import { addDays, zonedDateKey, type DateKey } from '../../lib/datetime';
import { whatsAppUrl } from '../../lib/whatsapp';

interface RebookInfo {
  readonly professional: ProfessionalLite;
  readonly firstName: string | undefined;
  readonly service: { readonly id: string; readonly name: string; readonly durationMinutes: number };
  readonly addOnIds: readonly string[];
  readonly guests: number;
  readonly offerState: RebookOfferState;
  readonly recommendedDate: string | undefined;
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
          if (portal.rebook === undefined) throw new ApiError('notFound');
          const profile = await loadPublicPage(portal.slug);
          const service = profile.services.find((candidate) => candidate.id === portal.rebook?.serviceId);
          return {
            professional: portal.professional,
            firstName: portal.clientFirstName,
            service: service === undefined
              ? { id: portal.rebook.serviceId, name: '', durationMinutes: 0 }
              : { id: service.id, name: service.name,
                durationMinutes: currentRebookMinutes(profile, service.id, portal.rebook.addOnIds, 0) ?? 0 },
            addOnIds: portal.rebook.addOnIds,
            guests: 0,
            offerState: rebookOfferState(profile, portal.rebook.serviceId, portal.rebook.addOnIds, 0),
            recommendedDate: portal.next?.recommendedDate,
            back: `/p/${token}`,
          };
        }
        const booking = await api.getBooking(token);
        const profile = await loadPublicPage(booking.professional.slug);
        const addOnIds = booking.addOns.map((addOn) => addOn.id);
        return {
          professional: booking.professional,
          firstName: booking.client.firstName,
          service: { id: booking.service.id, name: booking.service.name,
            durationMinutes: currentRebookMinutes(profile, booking.service.id, addOnIds, booking.guestCount)
              ?? booking.durationMinutes },
          addOnIds,
          guests: booking.guestCount,
          offerState: rebookOfferState(profile, booking.service.id, addOnIds, booking.guestCount),
          recommendedDate: undefined,
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

type ByDay = ReadonlyMap<DateKey, readonly string[]>;
type Load = { status: 'loading' } | { status: 'ready'; byDay: ByDay; moreByDay: ByDay } | { status: 'error'; error: unknown };

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
  const [result, setResult] = useState<BookingOutcome | null>(null);
  // One key per time she picks: a retry of the same request reuses it, a different time is a new attempt.
  const idempotencyKey = useMemo(() => newIdempotencyKey(), [pick]);

  useEffect(() => {
    if (info.offerState !== 'ready') return;
    let current = true;
    setLoad({ status: 'loading' });
    const from = zonedDateKey(Date.now(), pro.timeZoneID);
    api
      .getSlots({ slug: pro.slug, serviceId: info.service.id, addOnIds: info.addOnIds, guests: info.guests, from, to: addDays(from, DAYS_AHEAD) })
      .then(
        (response) => {
          if (!current) return;
          const byDay = groupByDay(response.slots, pro.timeZoneID);
          setLoad({ status: 'ready', byDay, moreByDay: groupByDay(response.more, pro.timeZoneID) });
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
  }, [token, attempt, info.offerState]);

  const byDay = load.status === 'ready' ? load.byDay : new Map<DateKey, readonly string[]>();
  const best = info.recommendedDate === undefined ? undefined : zonedDateKey(Date.parse(info.recommendedDate), pro.timeZoneID);
  const days = useMemo(() => [...byDay.keys()].sort().slice(0, DAY_CHOICES).map((key) => ({ key, best: key === best })), [byDay, best]);
  const slots = day === null ? [] : (byDay.get(day) ?? []);
  const moreSlots = day === null || load.status !== 'ready' ? [] : (load.moreByDay.get(day) ?? []);
  const message = whatsAppUrl(pro.whatsappE164, t('wa.book', { name: pro.firstName }));

  if (info.offerState !== 'ready') {
    return (
      <Screen top={<TopBar back={info.back} backLabel={t('cl3.back')} />}>
        <div class="stack">
          <Title>{info.firstName === undefined ? t('cl3.titleAnon') : t('cl3.title', { name: info.firstName })}</Title>
          <Notice kind="warning" testId="offer-unavailable">
            {t(info.offerState === 'guests' ? 'cl3.guestsUnavailable' : 'cl3.offerUnavailable', { name: pro.firstName })}
          </Notice>
        </div>
        <LinkButton to={{ kind: 'slug', slug: pro.slug, step: 'home' }} testId="choose-current-service">
          {t('bk1.book')}
        </LinkButton>
        {message === null ? null : (
          <ExternalLink href={message} variant="secondary" testId="message-pro">
            {t('bk1.messageWa', { name: pro.firstName })}
          </ExternalLink>
        )}
        <Footer />
      </Screen>
    );
  }

  const submit = async (): Promise<void> => {
    if (pick === null) return;
    setBusy(true);
    setFailure(null);
    try {
      const response = await api.rebook({ token, serviceId: info.service.id, addOnIds: info.addOnIds, startsAt: pick, idempotencyKey });
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
          <p class="lead" data-testid="done-text">{t('cl3.doneText', { service: result.serviceName })}</p>
        </div>
        <section class="card" data-testid="done-card">
          <b class="strong section"><bdi>{result.serviceName}</bdi></b>
          <p class="meta">{t('bk9.with', { name: pro.displayName, meta: format.minutes(Math.round((Date.parse(result.endsAt) - Date.parse(result.startsAt)) / 60_000)) })}</p>
          <hr class="rule" />
          <b class="strong">{format.weekdayDate(result.startsAt)}</b>
          <p class="moment tn">{format.time(result.startsAt)}</p>
        </section>
        <LinkButton to={routePath(manageRoute(result.manageToken))} testId="view-appointment">{t('bk8.view')}</LinkButton>
        <Footer />
      </Screen>
    );
  }
  if (result !== null) {
    const sent = result.status === 'pendingApproval';
    return (
      <Screen
        bar={
          sent || message === null ? undefined : (
            <ExternalLink href={message} variant="primary" testId="message-pro">
              {t('bk1.messageWa', { name: pro.firstName })}
            </ExternalLink>
          )
        }
      >
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
  return (
    <Screen
      top={<TopBar back={info.back} backLabel={t('cl3.back')} />}
      bar={
        <Button busy={busy} disabled={pick === null} onClick={() => { void submit(); }} testId="rebook">
          {pick === null ? t('cl3.pickFirst') : t('cl3.rebook', { when })}
        </Button>
      }
    >
      <div>
        <Title>{info.firstName === undefined ? t('cl3.titleAnon') : t('cl3.title', { name: info.firstName })}</Title>
        <p class="lead">{t('cl3.sub')}</p>
      </div>

      <section class="card row-flex">
        <Avatar name={pro.displayName} photo={pro.photo} />
        <div>
          <b class="strong"><bdi>{info.service.name}</bdi></b>
          <br />
          <span class="meta">{t('bk9.with', { name: pro.displayName, meta: format.minutes(info.service.durationMinutes) })}</span>
          {info.guests > 0 ? <p class="meta">{t('bk8.guest.unnamed', { count: info.guests })}</p> : null}
        </div>
      </section>

      {load.status === 'error' ? (
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
            <SlotChoices key={day ?? ''} slots={slots} more={moreSlots} selected={pick} formatter={format} onSelect={setPick} label={t('cl3.time')} />
          </div>
        </>
      )}
      <ErrorNotice error={failure} />
    </Screen>
  );
}
