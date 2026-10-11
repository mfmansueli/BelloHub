// The frame of every page opened with a personal link (/m/{token}, /p/{token}): it loads what the link opens,
// picks the page language from the professional's offered languages, and turns an unknown or expired link into a
// friendly page (docs/10 section 2). The token is only ever held in memory and the URL.

import type { ComponentChildren, JSX } from 'preact';
import { useEffect, useState } from 'preact/hooks';

import { ApiError } from '../api/errors';
import type { ProfessionalLite } from '../api/types';
import { FullState, SkeletonScreen } from '../components/Feedback';
import { languageForPage, setLanguage, useI18n } from '../i18n';
import { ProfessionalProvider } from './context';
import { useAsync } from './useAsync';

interface Props<T> {
  /** Loads what the link opens. Called again on retry. */
  readonly load: () => Promise<T>;
  readonly deps: readonly unknown[];
  readonly professionalOf: (data: T) => ProfessionalLite;
  readonly children: (data: T, update: (next: T) => void, reload: () => void) => ComponentChildren;
}

export function TokenLayout<T>({ load, deps, professionalOf, children }: Props<T>): JSX.Element {
  const { state, reload } = useAsync(load, deps);
  const { t, locale, ready } = useI18n();
  const [override, setOverride] = useState<{ base: unknown; data: T } | null>(null);

  const loaded = state.status === 'ready' ? state.data : null;
  // A newer load replaces what an action had updated.
  const data = override !== null && override.base === loaded ? override.data : loaded;
  const professional = data === null ? null : professionalOf(data);
  const wanted = professional === null ? null : languageForPage(professional.locales, professional.defaultLocale);
  useEffect(() => {
    if (wanted !== null && wanted !== locale) void setLanguage(wanted);
  }, [wanted, locale]);

  if (state.status === 'error') {
    const error = state.error;
    if (error instanceof ApiError && (error.code === 'notFound' || error.code === 'expired')) {
      return <ExpiredLink />;
    }
    return <FullState title={t('state.loadFailed.title')} text={t('state.loadFailed.text')} action={{ label: t('common.retry'), onClick: reload }} testId="load-failed" />;
  }
  if (data === null || professional === null || !ready || wanted !== locale) return <SkeletonScreen />;
  return (
    <ProfessionalProvider professional={professional}>
      {children(
        data,
        (next) => {
          setOverride({ base: loaded, data: next });
        },
        reload,
      )}
    </ProfessionalProvider>
  );
}

/**
 * An unknown or expired link: kind words and nothing else. The server never says who the link belonged to
 * (API.md section 3: `details` carries no personal data), so an unknown link and an expired one look the same.
 */
export function ExpiredLink(): JSX.Element {
  const { t } = useI18n();
  return <FullState title={t('state.expired.title')} text={t('state.expired.textNoName')} testId="expired" />;
}
