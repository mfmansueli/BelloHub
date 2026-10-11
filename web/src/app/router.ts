// A History API router in a screenful (docs/10 section 1: "no router library"). Paths are the contract of
// docs/10 section 2; Hosting rewrites every one of them to index.html.

import { createStore, useStore } from './store';

export type SlugStep =
  | 'home'
  | 'service'
  | 'professional'
  | 'time'
  | 'you'
  | 'verify'
  | 'firstVisit'
  | 'review'
  | 'booked'
  | 'find';

export type TokenStep = 'manage' | 'reschedule' | 'cancel' | 'form' | 'checkin' | 'data' | 'rebook';

export type Route =
  | { readonly kind: 'landing' }
  | { readonly kind: 'privacy' }
  | { readonly kind: 'notFound' }
  | { readonly kind: 'slug'; readonly slug: string; readonly step: SlugStep }
  | { readonly kind: 'manage'; readonly token: string; readonly step: TokenStep }
  | { readonly kind: 'portal'; readonly token: string; readonly step: 'home' | 'rebook' };

/** Words a professional can never claim as a slug, because they are routes or look official (docs/10 section 2). */
export const RESERVED_SLUGS: ReadonlySet<string> = new Set([
  'm', 'p', 'api', 'admin', 'app', 'www', 'privacy', 'terms', 'help', 'support', 'status', 'login', 'signin', 'signup',
  'assets', 'fonts', 'static', 'public', 'bello', 'bellohub', 'hub', 'mail', 'email', 'blog', 'docs', 'security', 'about',
  'contact', 'legal', 'cookies', 'sitemap', 'robots', 'favicon', 'index', 'manifest', 'well-known',
]);

const SLUG = /^[a-z0-9](?:[a-z0-9-]{1,28})[a-z0-9]$/;
const TOKEN = /^[A-Za-z0-9_-]{16,64}$/;

const SLUG_PATHS: Readonly<Record<string, SlugStep>> = {
  service: 'service',
  professional: 'professional',
  time: 'time',
  you: 'you',
  verify: 'verify',
  'first-visit': 'firstVisit',
  review: 'review',
  booked: 'booked',
  find: 'find',
};

const TOKEN_PATHS: Readonly<Record<string, TokenStep>> = {
  reschedule: 'reschedule',
  cancel: 'cancel',
  form: 'form',
  checkin: 'checkin',
  data: 'data',
  rebook: 'rebook',
};

export function isValidSlug(value: string): boolean {
  return SLUG.test(value) && !RESERVED_SLUGS.has(value);
}

export function isValidToken(value: string): boolean {
  return TOKEN.test(value);
}

/** The key of a waiting-list offer link (`/{slug}/time?offer=<holdKey>`, API.md 5.4), or null. */
export function offerKeyOf(search: string): string | null {
  const key = new URLSearchParams(search).get('offer');
  return key !== null && /^[A-Za-z0-9_-]{16,64}$/.test(key) ? key : null;
}

export function parseRoute(pathname: string): Route {
  const segments = pathname.split('/').filter((part) => part !== '');
  const [first, second, third] = segments;
  if (first === undefined) return { kind: 'landing' };
  if (first === 'privacy') return segments.length === 1 ? { kind: 'privacy' } : { kind: 'notFound' };
  if (first === 'm') {
    if (second === undefined || !isValidToken(second)) return { kind: 'notFound' };
    if (third === undefined) return { kind: 'manage', token: second, step: 'manage' };
    const step = TOKEN_PATHS[third];
    return step === undefined || segments.length > 3 ? { kind: 'notFound' } : { kind: 'manage', token: second, step };
  }
  if (first === 'p') {
    if (second === undefined || !isValidToken(second)) return { kind: 'notFound' };
    if (third === undefined) return { kind: 'portal', token: second, step: 'home' };
    return third === 'rebook' && segments.length === 3 ? { kind: 'portal', token: second, step: 'rebook' } : { kind: 'notFound' };
  }
  const slug = first.toLowerCase();
  if (!isValidSlug(slug)) return { kind: 'notFound' };
  if (second === undefined) return { kind: 'slug', slug, step: 'home' };
  const step = SLUG_PATHS[second];
  return step === undefined || segments.length > 2 ? { kind: 'notFound' } : { kind: 'slug', slug, step };
}

export function routePath(route: Route): string {
  switch (route.kind) {
    case 'landing':
      return '/';
    case 'privacy':
      return '/privacy';
    case 'notFound':
      return '/';
    case 'slug': {
      if (route.step === 'home') return `/${route.slug}`;
      const word = Object.entries(SLUG_PATHS).find(([, step]) => step === route.step)?.[0] ?? '';
      return `/${route.slug}/${word}`;
    }
    case 'manage': {
      if (route.step === 'manage') return `/m/${route.token}`;
      const word = Object.entries(TOKEN_PATHS).find(([, step]) => step === route.step)?.[0] ?? '';
      return `/m/${route.token}/${word}`;
    }
    case 'portal':
      return route.step === 'home' ? `/p/${route.token}` : `/p/${route.token}/rebook`;
  }
}

export const slugRoute = (slug: string, step: SlugStep = 'home'): Route => ({ kind: 'slug', slug, step });
export const manageRoute = (token: string, step: TokenStep = 'manage'): Route => ({ kind: 'manage', token, step });

export const routeStore = createStore<Route>(
  typeof window === 'undefined' ? { kind: 'landing' } : parseRoute(window.location.pathname),
);

export function useRoute(): Route {
  return useStore(routeStore);
}

/**
 * Set when the person moved to another screen, so the next screen takes focus on its heading and a screen reader
 * announces it. It is not set for the first load, where the browser does the right thing.
 */
export const focusAfterNavigation = { pending: false };

export function navigate(target: Route | string, replace = false): void {
  const path = typeof target === 'string' ? target : routePath(target);
  if (path === window.location.pathname) return;
  focusAfterNavigation.pending = true;
  if (replace) window.history.replaceState(null, '', path);
  else window.history.pushState(null, '', path);
  routeStore.set(parseRoute(path));
  window.scrollTo(0, 0);
}

export function startRouter(): () => void {
  const onPop = (): void => {
    focusAfterNavigation.pending = true;
    routeStore.set(parseRoute(window.location.pathname));
  };
  window.addEventListener('popstate', onPop);
  return () => {
    window.removeEventListener('popstate', onPop);
  };
}
