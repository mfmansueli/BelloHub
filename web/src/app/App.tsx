// The router outlet. One component per route of docs/10 section 2; every slug route sits inside the professional's
// layout (her page, her languages, her time zone), every token route inside the token layout.

import { Component, type ComponentChildren, type JSX } from 'preact';
import { useEffect } from 'preact/hooks';

import { api } from '../api/client';
import type { PublicProfile } from '../api/types';
import { FullState } from '../components/Feedback';
import { Link } from '../components/Button';
import { Footer, Screen, Title, useDocumentTitle } from '../components/Layout';
import { LegalDocumentView } from '../components/Legal';
import { ManagePage } from '../routes/manage/ManagePage';
import { ReschedulePage } from '../routes/manage/ReschedulePage';
import { CancelPage } from '../routes/manage/CancelPage';
import { CheckInPage } from '../routes/checkin/CheckInPage';
import { IntakePage } from '../routes/form/IntakePage';
import { MyDataPage } from '../routes/data/MyDataPage';
import { PortalPage } from '../routes/portal/PortalPage';
import { RebookPage } from '../routes/portal/RebookPage';
import { BookingHome } from '../routes/booking/BookingHome';
import { ConfirmedStep } from '../routes/booking/ConfirmedStep';
import { FindPage } from '../routes/booking/FindPage';
import { FirstVisitStep } from '../routes/booking/FirstVisitStep';
import { ReviewStep } from '../routes/booking/ReviewStep';
import { ServiceStep } from '../routes/booking/ServiceStep';
import { OfferStep } from '../routes/booking/OfferStep';
import { TimeStep } from '../routes/booking/TimeStep';
import { VerifyStep } from '../routes/booking/VerifyStep';
import { YouStep } from '../routes/booking/YouStep';
import { languageStore, useI18n, useT } from '../i18n';
import { LanguageChooser } from '../components/LanguageSheet';
import { navigate, offerKeyOf, slugRoute, useRoute, type Route, type SlugStep } from './router';
import { SlugLayout } from './pageData';
import { TokenLayout } from './TokenLayout';

function SlugStepView({ profile, step }: { profile: PublicProfile; step: SlugStep }): JSX.Element {
  switch (step) {
    case 'home':
      return <BookingHome profile={profile} />;
    case 'service':
      return <ServiceStep profile={profile} />;
    case 'professional':
      // One professional in v1 (D5): the screen exists in the design and sends her on.
      return <Redirect to={slugRoute(profile.slug, 'service')} />;
    case 'time': {
      const offer = offerKeyOf(window.location.search);
      return offer === null ? <TimeStep profile={profile} /> : <OfferStep profile={profile} holdKey={offer} />;
    }
    case 'you':
      return <YouStep profile={profile} />;
    case 'verify':
      return <VerifyStep profile={profile} />;
    case 'firstVisit':
      return <FirstVisitStep profile={profile} />;
    case 'review':
      return <ReviewStep profile={profile} />;
    case 'booked':
      return <ConfirmedStep profile={profile} />;
    case 'find':
      return <FindPage profile={profile} />;
  }
}

function Redirect({ to }: { to: Route }): null {
  useEffect(() => {
    navigate(to, true);
  }, [to]);
  return null;
}

function Landing(): JSX.Element {
  const t = useT();
  useDocumentTitle(t('landing.title'));
  return (
    <Screen>
      <LanguageChooser offered={[]} />
      <div class="state">
        <Title>{t('landing.title')}</Title>
        <p class="lead">{t('landing.text')}</p>
      </div>
      <Footer />
    </Screen>
  );
}

function PrivacyPage(): JSX.Element {
  const t = useT();
  useDocumentTitle(t('legal.privacyLink'));
  return (
    <Screen>
      <LanguageChooser offered={[]} />
      <LegalDocumentView document="privacy-policy" professionalName="Bello Hub" withTitle />
      <p class="center">
        <Link to="/" class="link-button">{t('landing.home')}</Link>
      </p>
      <Footer />
    </Screen>
  );
}

function NotFound(): JSX.Element {
  const t = useT();
  return <FullState title={t('state.notFound.title')} text={t('state.notFound.text')} testId="not-found" />;
}

function ManageView({ token, step }: { token: string; step: 'manage' | 'reschedule' | 'cancel' }): JSX.Element {
  return (
    <TokenLayout load={() => api.getBooking(token)} deps={[token, step]} professionalOf={(booking) => booking.professional}>
      {(booking) => {
        switch (step) {
          case 'manage':
            return <ManagePage token={token} booking={booking} />;
          case 'reschedule':
            return <ReschedulePage token={token} booking={booking} />;
          case 'cancel':
            return <CancelPage token={token} booking={booking} />;
        }
      }}
    </TokenLayout>
  );
}

function PortalView({ token }: { token: string }): JSX.Element {
  return (
    <TokenLayout load={() => api.getPortal(token)} deps={[token]} professionalOf={(portal) => portal.professional}>
      {(portal) => <PortalPage token={token} portal={portal} />}
    </TokenLayout>
  );
}

function RouteView({ route }: { route: Route }): JSX.Element {
  switch (route.kind) {
    case 'landing':
      return <Landing />;
    case 'privacy':
      return <PrivacyPage />;
    case 'notFound':
      return <NotFound />;
    case 'slug':
      return <SlugLayout slug={route.slug}>{(profile) => <SlugStepView profile={profile} step={route.step} />}</SlugLayout>;
    case 'manage':
      switch (route.step) {
        case 'manage':
        case 'reschedule':
        case 'cancel':
          return <ManageView token={route.token} step={route.step} />;
        case 'rebook':
          return <RebookPage token={route.token} kind="manage" />;
        case 'form':
          return <IntakePage token={route.token} />;
        case 'checkin':
          return <CheckInPage token={route.token} />;
        case 'data':
          return <MyDataPage token={route.token} />;
      }
      break;
    case 'portal':
      return route.step === 'home' ? <PortalView token={route.token} /> : <RebookPage token={route.token} kind="portal" />;
  }
  return <NotFound />;
}

/** The last line of defence: a friendly page, and only an error code ever leaves the component (docs/10 section 5). */
class ErrorBoundary extends Component<{ children: ComponentChildren }, { failed: boolean }> {
  override state = { failed: false };

  static override getDerivedStateFromError(): { failed: boolean } {
    return { failed: true };
  }

  override render(): ComponentChildren {
    if (!this.state.failed) return this.props.children;
    const t = languageStore.get().t;
    return (
      <FullState
        title={t('state.crash.title')}
        text={t('state.crash.text')}
        action={{ label: t('common.retry'), onClick: () => { window.location.reload(); } }}
        testId="crash"
      />
    );
  }
}

export function App(): JSX.Element {
  const route = useRoute();
  const { t } = useI18n();
  return (
    <ErrorBoundary>
      <a class="skip" href="#main">{t('common.skip')}</a>
      <RouteView route={route} />
    </ErrorBoundary>
  );
}
