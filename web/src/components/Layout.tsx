// The frame every screen shares: the top bar, the one centred column, the sticky action bar and the brand line.

import type { ComponentChildren, JSX } from 'preact';
import { useEffect } from 'preact/hooks';

import type { ProfessionalLite } from '../api/types';
import { useT } from '../i18n';
import { BrandMark, Icon } from './Icon';
import { Link } from './Button';
import { focusAfterNavigation, type Route } from '../app/router';

export function initialsOf(name: string): string {
  const words = name.trim().split(/\s+/).filter(Boolean);
  const letters = words.length >= 2 ? [words[0], words[1]] : [words[0]];
  return letters.map((word) => Array.from(word ?? '')[0] ?? '').join('').toLocaleUpperCase();
}

/** Only a small `data:image/` URI is accepted: the CSP allows images from the page and from `data:` and nothing else. */
export function safePhoto(photo: string | undefined): string | undefined {
  return photo !== undefined && /^data:image\/(png|jpeg|webp|gif);base64,[A-Za-z0-9+/=]+$/.test(photo) && photo.length < 200_000 ? photo : undefined;
}

interface AvatarProps {
  readonly name: string;
  readonly photo?: string | undefined;
  readonly size?: 'sm' | 'md' | 'lg';
}

export function Avatar({ name, photo, size = 'md' }: AvatarProps): JSX.Element {
  const safe = safePhoto(photo);
  return (
    <span class={`avatar${size === 'lg' ? ' avatar-lg' : size === 'sm' ? ' avatar-sm' : ''}`} aria-hidden="true">
      {safe === undefined ? initialsOf(name) : <img src={safe} alt="" width="96" height="96" />}
    </span>
  );
}

/** The professional's name beside her avatar, at the top of the token pages. */
export function ProHeader({ professional }: { professional: ProfessionalLite }): JSX.Element {
  return (
    <div class="brand-head">
      <Avatar name={professional.displayName} photo={professional.photo} />
      <bdi>{professional.displayName}</bdi>
    </div>
  );
}

interface TopBarProps {
  /** Where "back" goes. */
  readonly back: Route | string | null;
  readonly backLabel?: string;
  /** The current step and the number of steps, for the progress bar. */
  readonly step?: { readonly current: number; readonly total: number };
  readonly children?: ComponentChildren;
}

export function TopBar({ back, backLabel, step, children }: TopBarProps): JSX.Element {
  const t = useT();
  return (
    <header class="topbar">
      {back !== null ? (
        <Link to={back} class={backLabel === undefined ? 'back' : 'back back-text'} ariaLabel={backLabel === undefined ? t('common.back') : undefined} testId="back">
          <Icon name="back" />
          {backLabel}
        </Link>
      ) : null}
      {step !== undefined ? (
        <div class="progress" role="img" aria-label={t('common.step', { current: step.current, total: step.total })}>
          {Array.from({ length: step.total }, (_, index) => (
            <i key={index} class={index < step.current ? 'on' : ''} />
          ))}
        </div>
      ) : null}
      {children}
    </header>
  );
}

interface ScreenProps {
  readonly top?: ComponentChildren;
  readonly bar?: ComponentChildren;
  readonly children: ComponentChildren;
  /** Stagger the blocks in (docs/09 section 3.1). */
  readonly rise?: boolean;
}

export function Screen({ top, bar, children, rise = true }: ScreenProps): JSX.Element {
  const t = useT();
  useEffect(() => {
    if (!focusAfterNavigation.pending) return;
    focusAfterNavigation.pending = false;
    (document.getElementById('page-title') ?? document.getElementById('main'))?.focus({ preventScroll: true });
  }, []);
  return (
    <div class="page route">
      {top}
      <main id="main" class={`content${rise ? ' rise' : ''}`} tabIndex={-1}>
        {children}
      </main>
      {bar !== undefined && bar !== null ? (
        // A named region, so the action bar is a landmark like the header and the main area (axe "region").
        <div class="bar bar-rise" role="region" aria-label={t('common.actions')}>
          {bar}
        </div>
      ) : null}
    </div>
  );
}

export function Title({ children, id = 'page-title' }: { children: ComponentChildren; id?: string }): JSX.Element {
  return (
    <h1 id={id} class="title" tabIndex={-1}>
      {children}
    </h1>
  );
}

/** Keeps the browser tab title in step with the screen, so history and tabs make sense. */
export function useDocumentTitle(title: string | null): void {
  useEffect(() => {
    if (title !== null && title !== '') document.title = `${title} · Bello Hub`;
  }, [title]);
}

export function Footer(): JSX.Element {
  const t = useT();
  return (
    <div class="by">
      <BrandMark />
      <span>{t('common.by')}</span>
    </div>
  );
}
