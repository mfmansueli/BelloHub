// Bk-4: pick a day and a time (docs/10 section 3). Free start times come from the server for the TOTAL duration
// (service + add-ons + guests in sequence), shown in the business time zone, with the zone named and a warning when
// the device is somewhere else. Choosing a time takes a five-minute soft hold so two people do not collide.

import type { JSX } from 'preact';
import { useEffect, useMemo, useState } from 'preact/hooks';

import { api } from '../../api/client';
import { ApiError } from '../../api/errors';
import type { PublicProfile } from '../../api/types';
import { useFormatter } from '../../app/context';
import { navigate, slugRoute } from '../../app/router';
import { allowedStep, FLOW_STEPS } from '../../app/booking/machine';
import { groupByDay } from '../../app/booking/slotDays';
import { useBooking } from '../../app/booking/store';
import { selectedAddOns, totals } from '../../app/booking/summary';
import { Button } from '../../components/Button';
import { Calendar, SlotList } from '../../components/Calendar';
import { ErrorNotice, Notice } from '../../components/Feedback';
import { Screen, Title, TopBar, useDocumentTitle } from '../../components/Layout';
import { WaitlistSheet } from './WaitlistSheet';
import { useI18n } from '../../i18n';
import {
  addDays,
  addMonths,
  compareDateKeys,
  deviceClockDiffers,
  deviceTimeZone,
  instantFromZoned,
  monthBounds,
  toDateKey,
  zonedDateKey,
  zonedParts,
  type DateKey,
} from '../../lib/datetime';

type Load = { status: 'loading' } | { status: 'ready'; byDay: ReadonlyMap<DateKey, readonly string[]> } | { status: 'error'; error: unknown };

const NEXT_SLOTS_SHOWN = 4;

export function TimeStep({ profile }: { profile: PublicProfile }): JSX.Element | null {
  const { t } = useI18n();
  const format = useFormatter();
  const [state, dispatch] = useBooking(profile.slug, profile.regionCode);
  const zone = profile.timeZoneID;
  const { draft } = state;
  useDocumentTitle(t('bk4.title'));

  const redirect = allowedStep('time', state) !== 'time';
  useEffect(() => {
    if (redirect) navigate(slugRoute(profile.slug, 'service'), true);
  }, [redirect, profile.slug]);

  const today = useMemo(() => zonedDateKey(Date.now(), zone), [zone]);
  const horizonEnd = useMemo(() => addDays(today, profile.booking.maxDaysAhead), [today, profile.booking.maxDaysAhead]);
  const start = draft.startsAt === null ? today : zonedDateKey(Date.parse(draft.startsAt), zone);
  const [view, setView] = useState(() => {
    const parts = zonedParts(Date.parse(`${start}T12:00:00Z`), 'UTC');
    return { year: parts.year, month: parts.month };
  });
  const [load, setLoad] = useState<Load>({ status: 'loading' });
  const [attempt, setAttempt] = useState(0);
  const [day, setDay] = useState<DateKey | null>(draft.startsAt === null ? null : start);
  const [pick, setPick] = useState<string | null>(draft.startsAt);
  const [holding, setHolding] = useState(false);
  const [holdError, setHoldError] = useState<unknown>(null);
  const [waitlistOpen, setWaitlistOpen] = useState(false);
  const [advanced, setAdvanced] = useState(false);
  const [missing, setMissing] = useState(false);

  const service = profile.services.find((candidate) => candidate.id === draft.serviceId);
  const addOns = selectedAddOns(profile.addOns, draft.addOnIds);
  const summary = service === undefined ? null : totals(service, addOns, draft.guests);
  const deviceZone = deviceTimeZone();

  const requestKey = `${draft.serviceId ?? ''}|${draft.addOnIds.join(',')}|${draft.guests}|${view.year}-${view.month}|${attempt}`;
  useEffect(() => {
    if (service === undefined) return;
    let current = true;
    setLoad({ status: 'loading' });
    // The month as calendar days in the business zone, from today to the horizon (at most 42 days, API.md 5.2).
    const bounds = monthBounds(view.year, view.month, zone);
    const from = zonedDateKey(Math.max(bounds.start, Date.now()), zone);
    const to = zonedDateKey(Math.min(bounds.end - 1, instantFromZoned(horizonEnd, 12, 0, zone)), zone);
    if (compareDateKeys(from, to) > 0) {
      setLoad({ status: 'ready', byDay: new Map() });
      return;
    }
    api
      .getSlots({
        slug: profile.slug,
        serviceId: service.id,
        addOnIds: draft.addOnIds,
        guests: draft.guests,
        from,
        to,
        holdKey: draft.holdKey,
      })
      .then(
        (response) => {
          if (current) setLoad({ status: 'ready', byDay: groupByDay(response.slots, zone) });
        },
        (error: unknown) => {
          if (current) setLoad({ status: 'error', error });
        },
      );
    return () => {
      current = false;
    };
    // The request depends on exactly what `requestKey` spells out.
  }, [requestKey]);

  const byDay = load.status === 'ready' ? load.byDay : new Map<DateKey, readonly string[]>();
  const nextMonth = addMonths(view.year, view.month, 1);
  const canNext = compareDateKeys(toDateKey(nextMonth.year, nextMonth.month, 1), horizonEnd) <= 0;
  const todayParts = zonedParts(Date.parse(`${today}T12:00:00Z`), 'UTC');
  const canPrev = view.year * 12 + view.month > todayParts.year * 12 + todayParts.month;

  // When a day is not chosen yet, show the first free day, so times are on screen without an extra tap. When the
  // month has nothing free, look one month ahead once.
  useEffect(() => {
    if (load.status !== 'ready') return;
    if (day !== null && load.byDay.has(day)) return;
    const first = [...load.byDay.keys()].sort()[0];
    if (first !== undefined) {
      if (day === null || !load.byDay.has(day)) setDay(first);
    } else if (!advanced && canNext) {
      setAdvanced(true);
      setView(nextMonth);
    }
  }, [load]);

  const slots = day === null ? [] : (byDay.get(day) ?? []);
  const suggestions = state.slotTaken?.alternatives ?? [];
  const pickedInstant = pick === null ? null : Date.parse(pick);
  const showDeviceWarning = deviceClockDiffers(pickedInstant ?? Date.now(), zone, deviceZone);
  const place = profile.city ?? zone.split('/').at(-1)?.replace(/_/g, ' ') ?? zone;

  const selectSlot = (slot: string): void => {
    setPick(slot);
    setDay(zonedDateKey(Date.parse(slot), zone));
    setMissing(false);
    setHoldError(null);
  };

  const cont = async (): Promise<void> => {
    if (pick === null || service === undefined) {
      setMissing(true);
      return;
    }
    setHolding(true);
    setHoldError(null);
    try {
      const hold = await api.holdSlot({
        slug: profile.slug,
        serviceId: service.id,
        addOnIds: draft.addOnIds,
        guests: draft.guests,
        startsAt: pick,
        holdKey: draft.holdKey,
      });
      dispatch({ type: 'chooseSlot', startsAt: pick, holdExpiresAt: hold.expiresAt });
      navigate(slugRoute(profile.slug, 'you'));
    } catch (error) {
      if (error instanceof ApiError && error.code === 'slotTaken') {
        // Show what is free now, after the time she wanted.
        const next = [...byDay.values()].flat().filter((slot) => slot > pick).slice(0, NEXT_SLOTS_SHOWN);
        dispatch({ type: 'slotTaken', alternatives: next });
        setPick(null);
        setAttempt((value) => value + 1);
      } else {
        setHoldError(error);
      }
    } finally {
      setHolding(false);
    }
  };

  if (redirect) return null;

  const bar = (
    <>
      {pick !== null && showDeviceWarning ? (
        <p class="bar-note" data-testid="device-zone">
          {t('bk4.zoneYours', { time: format.timeOnDevice(pick) })}
        </p>
      ) : null}
      <Button busy={holding} disabled={pick === null} onClick={() => { void cont(); }} testId="continue">
        {t('common.continue')}
      </Button>
    </>
  );

  const noneThisMonth = load.status === 'ready' && byDay.size === 0;

  return (
    <Screen top={<TopBar back={slugRoute(profile.slug, 'service')} step={{ current: 2, total: FLOW_STEPS }} />} bar={bar}>
      <div>
        <Title>{t('bk4.title')}</Title>
        <p class="lead">
          {[service?.name, summary === null ? '' : format.minutes(summary.totalMinutes), profile.displayName].filter(Boolean).join(' · ')}
        </p>
      </div>

      {state.slotTaken === null ? null : (
        <Notice kind="warning" icon="alert" live="assertive" title={t('bk4.taken.title')} testId="slot-taken">
          {suggestions.length === 0 ? (
            t('bk4.taken.none')
          ) : (
            <div class="chips mt-sm">
              {suggestions.map((slot) => (
                <button key={slot} type="button" class="chip" data-testid={`suggest-${slot}`} onClick={() => { selectSlot(slot); }}>
                  <bdi>{`${format.shortDate(slot)} · ${format.time(slot)}`}</bdi>
                </button>
              ))}
            </div>
          )}
        </Notice>
      )}

      <Calendar
        year={view.year}
        month={view.month}
        formatter={format}
        selected={day}
        today={today}
        isAvailable={(key) => byDay.has(key)}
        onSelect={(key) => { setDay(key); setPick(null); }}
        onMonth={(delta) => { setAdvanced(true); setView((current) => addMonths(current.year, current.month, delta)); }}
        canPrev={canPrev}
        canNext={canNext}
      />

      <div aria-live="polite" aria-busy={load.status === 'loading' ? 'true' : 'false'}>
        {load.status === 'error' ? (
          <div class="stack">
            <ErrorNotice error={load.error} />
            <Button variant="secondary" inline onClick={() => { setAttempt((value) => value + 1); }}>
              {t('common.retry')}
            </Button>
          </div>
        ) : load.status === 'loading' ? (
          <div class="skeleton skeleton-block" />
        ) : noneThisMonth ? (
          <p class="lead" data-testid="no-times">
            {canNext ? t('bk4.noTimesMonth') : t('bk4.noTimesEnd', { date: format.longDateOf(horizonEnd) })}
          </p>
        ) : day === null ? null : (
          <div class="stack-sm">
            <h2 class="section">{format.longDateOf(day)}</h2>
            <SlotList slots={slots} selected={pick} formatter={format} onSelect={selectSlot} label={t('bk4.timesFor', { date: format.longDateOf(day) })} />
          </div>
        )}
      </div>

      <p class="foot-note" data-testid="zone-note">
        {t('bk4.zone', { place })}
        {showDeviceWarning ? ` ${t('bk4.zoneDevice')}` : ''}
      </p>

      {missing ? (
        <Notice kind="warning" icon="alert" live="assertive" testId="time-missing">
          {t('bk4.pickError')}
        </Notice>
      ) : null}
      <ErrorNotice error={holdError} />

      <button type="button" class="card list-row" onClick={() => { setWaitlistOpen(true); }} aria-haspopup="dialog" data-testid="waitlist-open">
        <span class="grow">
          <b class="strong">{t('bk4.waitTitle')}</b>
          <span class="sub">{t('bk4.waitSub', { name: profile.firstName })}</span>
        </span>
      </button>

      <WaitlistSheet open={waitlistOpen} onClose={() => { setWaitlistOpen(false); }} profile={profile} serviceId={draft.serviceId} />
    </Screen>
  );
}
