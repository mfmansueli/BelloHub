// A small line-icon set (24-pt grid, round caps), drawn inline so there is no icon font and no extra request.
// Icons are decorative: they carry `aria-hidden`, and an icon-only control gets its label from the control.

import type { JSX } from 'preact';

const PATHS = {
  chevron: 'm9.5 6 6 6-6 6',
  back: 'm14.5 6-6 6 6 6',
  check: 'm5 12.5 4.5 4.5L19 7.5',
  x: 'M6 6l12 12M18 6 6 18',
  pin: 'M12 20.5s-6-5.6-6-10.5a6 6 0 0 1 12 0c0 4.9-6 10.5-6 10.5zM12 12.2a2.2 2.2 0 1 0 0-4.4 2.2 2.2 0 0 0 0 4.4z',
  globe: 'M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17zM3.5 12h17M12 3.5c2.5 2.5 3.5 5.5 3.5 8.5s-1 6-3.5 8.5c-2.5-2.5-3.5-5.5-3.5-8.5s1-6 3.5-8.5z',
  calendar: 'M5 6.5h14a1 1 0 0 1 1 1V19a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7.5a1 1 0 0 1 1-1zM4 10.5h16M8 4v4M16 4v4',
  calendarPlus: 'M5 6.5h14a1 1 0 0 1 1 1V19a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7.5a1 1 0 0 1 1-1zM4 10.5h16M8 4v4M16 4v4M12 13v4.5M9.75 15.25h4.5',
  link: 'M10 14a3.5 3.5 0 0 0 5 0l3-3a3.5 3.5 0 0 0-5-5l-.8.8M14 10a3.5 3.5 0 0 0-5 0l-3 3a3.5 3.5 0 0 0 5 5l.8-.8',
  lock: 'M6.5 11h11a1 1 0 0 1 1 1v6.5a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1V12a1 1 0 0 1 1-1zM8.5 11V8a3.5 3.5 0 0 1 7 0v3',
  user: 'M12 12.5a3.8 3.8 0 1 0 0-7.6 3.8 3.8 0 0 0 0 7.6zM5 19.5c.6-3.2 3.4-5 7-5s6.4 1.8 7 5',
  clock: 'M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17zM12 7.5V12l3 2',
  mail: 'M5 6.5h14a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1zM4.5 8l7.5 5.5L19.5 8',
  chat: 'M5 5.5h14a1 1 0 0 1 1 1v9.5a1 1 0 0 1-1 1h-7l-4 3v-3H5a1 1 0 0 1-1-1V6.5a1 1 0 0 1 1-1z',
  camera: 'M5 8h2.2l1.3-2h7l1.3 2H19a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1zM12 16.5a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4z',
  trash: 'M5 7h14M10 7V5h4v2M7 7l.8 12h8.4L17 7M10 11v5M14 11v5',
  info: 'M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17zM12 11v5.5M12 7.8v.4',
  alert: 'M12 4 3.5 19h17L12 4zM12 10v4.5M12 17v.3',
  copy: 'M9 9h9a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1zM5.5 15H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v.5',
  download: 'M12 4v11M7.5 11l4.5 4.5 4.5-4.5M5 19.5h14',
  shield: 'M12 3.5 5 6v5.5c0 4.2 2.9 7.3 7 9 4.1-1.7 7-4.8 7-9V6l-7-2.5zM9 12l2.2 2.2L15.2 10',
  doc: 'M7 3.5h7l4 4V20a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4.5a1 1 0 0 1 1-1zM13.5 3.5V8H18M9 12.5h6M9 16h6',
  image: 'M5 5h14a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1zM4 16l4.5-4.5 4 4 3-3L20 16M9 9.5v.1',
  repeat: 'M5 12a7 7 0 0 1 12-4.9L19 9M19 4.5V9h-4.5M19 12a7 7 0 0 1-12 4.9L5 15M5 19.5V15h4.5',
  sparkle: 'M12 4l1.7 4.8L18.5 10.5l-4.8 1.7L12 17l-1.7-4.8L5.5 10.5l4.8-1.7L12 4z',
} as const;

export type IconName = keyof typeof PATHS;

/** Directional icons mirror in right-to-left languages by CSS (`.icon-dir`). */
const DIRECTIONAL: ReadonlySet<IconName> = new Set<IconName>(['chevron', 'back']);

interface IconProps {
  readonly name: IconName;
  readonly class?: string;
}

export function Icon({ name, class: className }: IconProps): JSX.Element {
  const classes = ['icon', DIRECTIONAL.has(name) ? 'icon-dir' : '', className ?? ''].filter(Boolean).join(' ');
  return (
    <svg class={classes} viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <path d={PATHS[name]} />
    </svg>
  );
}

/** The Bello Hub mark, drawn (never an image). */
export function BrandMark(): JSX.Element {
  return (
    <svg viewBox="0 0 28 28" width="18" height="18" aria-hidden="true" focusable="false">
      <rect class="bm-bg" width="28" height="28" rx="9" />
      <path class="bm-fg" d="M10 6.5v15" stroke-width="2.2" stroke-linecap="round" />
      <circle class="bm-fg" cx="15.2" cy="16" r="4.6" stroke-width="2.2" fill="none" />
      <circle class="bm-dot" cx="10" cy="6.5" r="1.6" />
    </svg>
  );
}

/** The success check, drawn once (the seal animates its stroke). */
export function CheckMark(): JSX.Element {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <path d="m5 12.5 4.5 4.5L19 7.5" />
    </svg>
  );
}
