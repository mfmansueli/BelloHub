// Cl-2: the client portal (/p/{token}). Next session, past visits, and the aftercare and products the professional
// chose to share. She sees only what she published ("You only see what Maria chooses to share with you"), as
// API.md 5.16 returns it. The sealed pages (form, check-in, data) open from a booking's own link, not from here.

import type { JSX } from 'preact';
import { useRef, useState } from 'preact/hooks';

import type { PortalView } from '../../api/types';
import { useFormatter } from '../../app/context';
import type { Route } from '../../app/router';
import { Link, LinkButton } from '../../components/Button';
import { Icon } from '../../components/Icon';
import { StatusChip } from '../../components/Feedback';
import { Footer, Avatar, Screen, useDocumentTitle } from '../../components/Layout';
import { useI18n } from '../../i18n';

type TabId = 'appts' | 'journey' | 'care';
const TABS: readonly { id: TabId; key: string }[] = [
  { id: 'appts', key: 'cl2.tab.appts' },
  { id: 'journey', key: 'cl2.tab.journey' },
  { id: 'care', key: 'cl2.tab.care' },
];

export function PortalPage({ token, portal }: { token: string; portal: PortalView }): JSX.Element {
  const { t } = useI18n();
  const pro = portal.professional;
  const [tab, setTab] = useState<TabId>('appts');
  const list = useRef<HTMLDivElement>(null);
  useDocumentTitle(t('cl2.hi', { name: portal.clientFirstName }));

  const rebook: Route | string = `/p/${token}/rebook`;
  const canRebook = portal.rebook !== undefined;

  const onKey = (event: KeyboardEvent, index: number): void => {
    // The tabs pattern of the ARIA practices: arrows move (mirrored in right-to-left), Home and End jump.
    const rtl = document.documentElement.dir === 'rtl';
    const step = event.key === 'ArrowRight' ? (rtl ? -1 : 1) : event.key === 'ArrowLeft' ? (rtl ? 1 : -1) : 0;
    const target = event.key === 'Home' ? 0 : event.key === 'End' ? TABS.length - 1 : step === 0 ? null : (index + step + TABS.length) % TABS.length;
    if (target === null) return;
    event.preventDefault();
    const next = TABS[target];
    if (next === undefined) return;
    setTab(next.id);
    // Focus moves now, not in a timer: the panel renders in a microtask, and a second key press arriving before a
    // timer fired would still act on the old tab.
    list.current?.querySelector<HTMLElement>(`#tab-${next.id}`)?.focus();
  };

  return (
    <Screen
      bar={
        canRebook ? (
          <LinkButton to={rebook} testId="book-again-bar">
            {t('cl2.bookAgain')}
          </LinkButton>
        ) : undefined
      }
      top={
        <header class="topbar">
          <div class="brand-head grow">
            <Avatar name={pro.displayName} photo={pro.photo} />
            <bdi>{pro.displayName}</bdi>
          </div>
          <Avatar name={portal.clientFirstName} size="sm" />
        </header>
      }
    >
      <div>
        <h1 id="page-title" class="title" tabIndex={-1}>
          {t('cl2.hi', { name: portal.clientFirstName })}
        </h1>
        <p class="lead">{t('cl2.sub', { name: pro.displayName })}</p>
      </div>

      <div class="tabs" role="tablist" aria-label={t('cl2.tabs')} ref={list}>
        {TABS.map((item, index) => (
          <button
            key={item.id}
            id={`tab-${item.id}`}
            type="button"
            role="tab"
            class="tab"
            aria-selected={tab === item.id ? 'true' : 'false'}
            aria-controls={`panel-${item.id}`}
            tabIndex={tab === item.id ? 0 : -1}
            data-testid={`tab-${item.id}`}
            onClick={() => { setTab(item.id); }}
            onKeyDown={(event) => { onKey(event, index); }}
          >
            {t(item.key)}
          </button>
        ))}
      </div>

      <div role="tabpanel" id={`panel-${tab}`} aria-labelledby={`tab-${tab}`} class="stack-lg" tabIndex={0}>
        {tab === 'appts' ? <Appointments portal={portal} rebook={canRebook ? rebook : null} /> : null}
        {tab === 'journey' ? <Journey portal={portal} /> : null}
        {tab === 'care' ? <Aftercare portal={portal} /> : null}
      </div>

      <Footer />
    </Screen>
  );
}

function Appointments({ portal, rebook }: { portal: PortalView; rebook: Route | string | null }): JSX.Element {
  const { t } = useI18n();
  const format = useFormatter();
  return (
    <>
      {portal.next === undefined ? null : (
        <section class="hero stack-sm" aria-labelledby="next-title" data-testid="next-session">
          <p class="meta" id="next-title">{t('cl2.next')}</p>
          <p class="section"><bdi>{portal.next.serviceName}</bdi></p>
          {portal.next.recommendedDate === undefined ? null : (
            <p class="meta">{t('cl2.recommended', { date: format.longDate(portal.next.recommendedDate) })}</p>
          )}
          {rebook === null ? null : (
            <Link to={rebook} class="btn btn-hero" testId="book-again">
              {t('cl2.bookAgain')}
            </Link>
          )}
        </section>
      )}

      {portal.upcoming.length === 0 ? null : (
        <ul class="card card-flush list" data-testid="upcoming">
          {portal.upcoming.map((visit, index) => (
            <li key={index} class="list-row">
              <span class="grow">
                <span class="meta">{t('cl2.upcoming')}</span>
                <b class="strong"><bdi>{visit.serviceName}</bdi></b>
                <span class="sub">{`${format.weekdayDate(visit.startsAt)} · ${format.time(visit.startsAt)}`}</span>
              </span>
            </li>
          ))}
        </ul>
      )}

      {portal.past.length === 0 ? null : (
        <section aria-labelledby="past-title">
          <h2 id="past-title" class="meta strong">{t('cl2.past')}</h2>
          <ul class="card card-flush list mt-sm">
            {portal.past.map((visit, index) => (
              <li key={index} class="list-row">
                <span class="grow">
                  <b class="strong"><bdi>{visit.serviceName}</bdi></b>
                  <span class="sub">{format.dayMonth(visit.date)}</span>
                </span>
                <StatusChip kind="done">{t('cl2.completed')}</StatusChip>
              </li>
            ))}
          </ul>
        </section>
      )}

    </>
  );
}

function Journey({ portal }: { portal: PortalView }): JSX.Element {
  const { t } = useI18n();
  const format = useFormatter();
  const shared = portal.past.filter((visit) => visit.summary !== undefined && visit.summary !== '');
  return (
    <>
      {shared.length === 0 ? <p class="lead" data-testid="journey-empty">{t('cl2.journeyEmpty', { name: portal.professional.firstName })}</p> : null}
      <ol class="stack">
        {shared.map((visit, index) => (
          <li key={index} class="card stack-sm">
            <p class="meta">{format.dayMonth(visit.date)}</p>
            <b class="strong"><bdi>{visit.serviceName}</bdi></b>
            <div class="well">
              <b class="strong">{t('cl2.shared', { name: portal.professional.firstName })}</b>
              <p>{visit.summary}</p>
            </div>
          </li>
        ))}
      </ol>
      <p class="well well-icon">
        <Icon name="lock" />
        <span>{t('cl2.only', { name: portal.professional.firstName })}</span>
      </p>
    </>
  );
}

function Aftercare({ portal }: { portal: PortalView }): JSX.Element {
  const { t } = useI18n();
  const format = useFormatter();
  return (
    <>
      {portal.aftercare.length === 0 ? <p class="lead" data-testid="care-empty">{t('cl2.careEmpty', { name: portal.professional.firstName })}</p> : null}
      {portal.aftercare.map((entry, index) => (
        <section key={index} class="card stack-sm">
          <h2 class="strong">{entry.date === undefined ? entry.title : t('cl2.after', { service: entry.title, date: format.dayMonth(entry.date) })}</h2>
          <ul class="check-list">
            {entry.lines.map((line, i) => (
              <li key={i}><Icon name="check" /><span>{line}</span></li>
            ))}
          </ul>
        </section>
      ))}
      {portal.products.length === 0 ? null : (
        <section class="card stack-sm">
          <h2 class="strong">{t('cl2.products', { name: portal.professional.firstName })}</h2>
          <ul class="list">
            {portal.products.map((product, index) => (
              <li key={index} class="list-row">
                <span class="grow"><b><bdi>{product.name}</bdi></b><span class="sub">{product.note ?? t('cl2.usedIn')}</span></span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </>
  );
}
