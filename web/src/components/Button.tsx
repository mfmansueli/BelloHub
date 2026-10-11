// Buttons and links. One primary action per screen; destructive actions are never the visual primary.

import type { ComponentChildren, JSX } from 'preact';

import { navigate, routePath, type Route } from '../app/router';

export type ButtonVariant = 'primary' | 'secondary' | 'tertiary' | 'hero';

function classes(variant: ButtonVariant, inline: boolean, extra?: string): string {
  return ['btn', `btn-${variant}`, inline ? 'btn-inline' : '', extra ?? ''].filter(Boolean).join(' ');
}

interface ButtonProps {
  readonly variant?: ButtonVariant;
  readonly inline?: boolean;
  /** The dimmed state keeps the button focusable and announced ("dimmed"); a press explains what is missing. */
  readonly disabled?: boolean;
  readonly busy?: boolean;
  readonly onClick?: (event: MouseEvent) => void;
  readonly children: ComponentChildren;
  readonly id?: string;
  readonly type?: 'button' | 'submit';
  readonly describedBy?: string;
  readonly testId?: string;
  readonly class?: string;
}

export function Button({ variant = 'primary', inline = false, disabled = false, busy = false, onClick, children, id, type = 'button', describedBy, testId, class: extra }: ButtonProps): JSX.Element {
  return (
    <button
      type={type}
      id={id}
      class={classes(variant, inline, extra)}
      aria-disabled={disabled || busy ? 'true' : undefined}
      aria-busy={busy ? 'true' : undefined}
      aria-describedby={describedBy}
      data-testid={testId}
      onClick={(event) => {
        if (disabled || busy) {
          event.preventDefault();
          return;
        }
        onClick?.(event);
      }}
    >
      {busy ? <span class="spinner" aria-hidden="true" /> : null}
      {children}
    </button>
  );
}

function plainClick(event: MouseEvent): boolean {
  return event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey && !event.defaultPrevented;
}

interface LinkProps {
  readonly to: Route | string;
  readonly children: ComponentChildren;
  readonly class?: string;
  readonly replace?: boolean;
  readonly ariaLabel?: string;
  readonly testId?: string;
  readonly id?: string;
}

/** An internal link: a real `<a href>` (so it can be opened in a new tab and read by assistive tech) that routes in place. */
export function Link({ to, children, class: className, replace = false, ariaLabel, testId, id }: LinkProps): JSX.Element {
  const href = typeof to === 'string' ? to : routePath(to);
  return (
    <a
      id={id}
      href={href}
      class={className}
      aria-label={ariaLabel}
      data-testid={testId}
      onClick={(event) => {
        if (!plainClick(event)) return;
        event.preventDefault();
        navigate(to, replace);
      }}
    >
      {children}
    </a>
  );
}

interface LinkButtonProps extends Omit<LinkProps, 'class'> {
  readonly variant?: ButtonVariant;
  readonly inline?: boolean;
}

export function LinkButton({ variant = 'primary', inline = false, ...rest }: LinkButtonProps): JSX.Element {
  return <Link {...rest} class={classes(variant, inline)} />;
}

interface ExternalProps {
  readonly href: string;
  readonly children: ComponentChildren;
  readonly variant?: ButtonVariant;
  readonly class?: string;
  readonly testId?: string;
  readonly download?: string;
}

/** A link that leaves the page (WhatsApp, Google Calendar): new tab, no opener, no referrer. */
export function ExternalLink({ href, children, variant, class: className, testId, download }: ExternalProps): JSX.Element {
  return (
    <a href={href} target="_blank" rel="noopener noreferrer" class={variant === undefined ? className : classes(variant, false, className)} data-testid={testId} download={download}>
      {children}
    </a>
  );
}

interface IconButtonProps {
  readonly label: string;
  readonly onClick: () => void;
  readonly disabled?: boolean;
  readonly children: ComponentChildren;
  readonly testId?: string;
}

/** An icon-only control: always labelled, always at least 44 by 44. */
export function IconButton({ label, onClick, disabled = false, children, testId }: IconButtonProps): JSX.Element {
  return (
    <button
      type="button"
      class="icon-btn"
      aria-label={label}
      aria-disabled={disabled ? 'true' : undefined}
      data-testid={testId}
      onClick={() => {
        if (!disabled) onClick();
      }}
    >
      {children}
    </button>
  );
}
