// The professional's public page, loaded once per slug and shared by every screen of her booking flow. The layout
// also picks the page language from what she offers (docs/07 section 7) and puts her in scope for the formatters.

import type { ComponentChildren, JSX } from 'preact';
import { useEffect } from 'preact/hooks';

import { api } from '../api/client';
import { ApiError } from '../api/errors';
import type { PublicProfile } from '../api/types';
import { FullState, SkeletonScreen } from '../components/Feedback';
import { languageForPage, setLanguage, useI18n } from '../i18n';
import { ProfessionalProvider } from './context';
import { useAsync } from './useAsync';

/** One request per slug (the client caches it); a failure is forgotten so a retry asks again. */
export function loadPublicPage(slug: string): Promise<PublicProfile> {
  return api.getPublicPage(slug);
}

export function forgetPublicPage(slug: string): void {
  api.forgetPublicPage(slug);
}

interface SlugLayoutProps {
  readonly slug: string;
  readonly children: (profile: PublicProfile) => ComponentChildren;
}

export function SlugLayout({ slug, children }: SlugLayoutProps): JSX.Element {
  const { state, reload } = useAsync(() => loadPublicPage(slug), [slug]);
  const { t, locale, ready } = useI18n();

  const profile = state.status === 'ready' ? state.data : null;
  const wanted = profile === null ? null : languageForPage(profile.locales, profile.defaultLocale);
  useEffect(() => {
    if (wanted !== null && wanted !== locale) void setLanguage(wanted);
  }, [wanted, locale]);

  if (state.status === 'error') {
    const notFound = state.error instanceof ApiError && state.error.code === 'notFound';
    return notFound ? (
      <FullState title={t('state.notFound.title')} text={t('state.notFound.text')} testId="not-found" />
    ) : (
      <FullState
        title={t('state.loadFailed.title')}
        text={t('state.loadFailed.text')}
        action={{ label: t('common.retry'), onClick: () => { forgetPublicPage(slug); reload(); } }}
        testId="load-failed"
      />
    );
  }
  if (profile === null || !ready || wanted !== locale) return <SkeletonScreen />;
  return <ProfessionalProvider professional={profile}>{children(profile)}</ProfessionalProvider>;
}
