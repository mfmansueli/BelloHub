// Notices, status chips, the success seal, loading skeletons and full-page states (empty, error, expired).

import type { ComponentChildren, JSX } from 'preact';

import { useT } from '../i18n';
import { ApiError } from '../api/errors';
import type { ApiErrorCode } from '../api/types';
import { Button } from './Button';
import { CheckMark, Icon, type IconName } from './Icon';
import { Screen, Title, useDocumentTitle } from './Layout';

export type NoticeKind = 'info' | 'warning' | 'safety' | 'quiet';

interface NoticeProps {
  readonly kind?: NoticeKind;
  readonly icon?: IconName;
  readonly title?: string;
  readonly children?: ComponentChildren;
  /** Errors and countdowns announce themselves politely; a message that must interrupt uses `alert`. */
  readonly live?: 'polite' | 'assertive';
  readonly testId?: string;
}

export function Notice({ kind = 'quiet', icon, title, children, live, testId }: NoticeProps): JSX.Element {
  return (
    <div class={`notice notice-${kind}`} role={live === 'assertive' ? 'alert' : live === 'polite' ? 'status' : undefined} data-testid={testId}>
      {icon === undefined ? null : <Icon name={icon} />}
      <div class="grow">
        {title === undefined ? null : <span class="strong">{title}</span>}
        {children}
      </div>
    </div>
  );
}

export type StatusKind = 'confirmed' | 'pending' | 'next' | 'done' | 'attention';

export function StatusChip({ kind, children }: { kind: StatusKind; children: ComponentChildren }): JSX.Element {
  return <span class={`status status-${kind}`}>{children}</span>;
}

export function Seal({ tone = 'sage' }: { tone?: 'sage' | 'rose' | 'amber' }): JSX.Element {
  return (
    <span class={`seal${tone === 'sage' ? '' : ` seal-${tone}`}`} aria-hidden="true">
      <CheckMark />
    </span>
  );
}

export function SkeletonScreen(): JSX.Element {
  return (
    <Screen rise={false}>
      <div class="stack-lg" aria-busy="true">
        <div class="skeleton w-40 h-28" />
        <div class="skeleton skeleton-block" />
        <div class="skeleton skeleton-block" />
        <div class="skeleton skeleton-block" />
      </div>
    </Screen>
  );
}

interface FullStateProps {
  readonly title: string;
  readonly text?: string;
  readonly action?: { readonly label: string; readonly onClick: () => void };
  readonly children?: ComponentChildren;
  readonly testId?: string;
}

/** A friendly page for what cannot be shown: an expired link, a missing page, a failed load. */
export function FullState({ title, text, action, children, testId }: FullStateProps): JSX.Element {
  useDocumentTitle(title);
  return (
    <Screen>
      <div class="state" data-testid={testId}>
        <Title>{title}</Title>
        {text === undefined ? null : <p class="lead">{text}</p>}
        {action === undefined ? null : (
          <Button variant="secondary" inline onClick={action.onClick}>
            {action.label}
          </Button>
        )}
        {children}
      </div>
    </Screen>
  );
}

const ERROR_KEYS: Readonly<Record<ApiErrorCode, string>> = {
  invalidInput: 'err.invalidInput',
  notFound: 'err.generic',
  expired: 'err.generic',
  rateLimited: 'err.rateLimited',
  appCheck: 'err.appCheck',
  slotTaken: 'err.slotTaken',
  paused: 'err.generic',
  codeInvalid: 'err.generic',
  codeExpired: 'err.generic',
  tooManyAttempts: 'err.rateLimited',
  notAllowed: 'err.notAllowed',
  tooLarge: 'err.tooLarge',
  keyMismatch: 'err.generic',
  unavailable: 'err.unavailable',
  network: 'err.network',
  timeout: 'err.timeout',
  server: 'err.generic',
};

/** The sentence for an error: what happened and how to fix it, with no code and no detail. */
export function useErrorText(): (error: unknown) => string {
  const t = useT();
  return (error) => t(ERROR_KEYS[error instanceof ApiError ? error.code : 'network']);
}

export function ErrorNotice({ error, testId = 'error' }: { error: unknown; testId?: string }): JSX.Element | null {
  const text = useErrorText();
  if (error === null || error === undefined) return null;
  return (
    <Notice kind="warning" icon="alert" live="assertive" testId={testId}>
      {text(error)}
    </Notice>
  );
}
