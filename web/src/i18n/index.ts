// The page's language: which of the fourteen localizations is active, its catalog (loaded on demand, one JSON per
// language so the initial bundle holds), and the hooks components use to read it.

import { createStore, useStore } from '../app/store';
import { STORAGE_KEYS, readLocal, writeLocal } from '../lib/storage';
import { DEFAULT_LOCALE, chooseLocale, directionOf, type Direction, type LocaleId } from '../lib/locales';
import { translate, type Catalog, type Params } from './translate';

const loaders = import.meta.glob<{ default: Catalog }>(
  './{pt-BR,pt-PT,es-MX,es-419,es,en,en-GB,it,fr,de,tr,id,hi,ar}.json',
);

const cache = new Map<LocaleId, Catalog>();
const pending = new Map<LocaleId, Promise<Catalog>>();

export function loadCatalog(id: LocaleId): Promise<Catalog> {
  const cached = cache.get(id);
  if (cached !== undefined) return Promise.resolve(cached);
  let promise = pending.get(id);
  if (promise === undefined) {
    const loader = loaders[`./${id}.json`];
    promise =
      loader === undefined
        ? Promise.reject(new Error('no catalog'))
        : loader().then((module) => {
            cache.set(id, module.default);
            return module.default;
          });
    pending.set(id, promise);
  }
  return promise;
}

export type Translate = (key: string, params?: Params) => string;

export function makeTranslate(catalog: Catalog, locale: LocaleId): Translate {
  const numbers = new Intl.NumberFormat(locale);
  const plural = new Intl.PluralRules(locale);
  const context = {
    isolate: directionOf(locale) === 'rtl',
    pluralCategory: (count: number): Intl.LDMLPluralRule => plural.select(count),
    formatNumber: (value: number): string => numbers.format(value),
  };
  return (key, params) => translate(catalog, key, params, context);
}

const unready: Translate = (key) => key;

export interface LanguageState {
  readonly locale: LocaleId;
  readonly direction: Direction;
  readonly ready: boolean;
  readonly t: Translate;
}

export const languageStore = createStore<LanguageState>({
  locale: DEFAULT_LOCALE,
  direction: 'ltr',
  ready: false,
  t: unready,
});

function applyToDocument(id: LocaleId): void {
  const root = document.documentElement;
  root.lang = id;
  root.dir = directionOf(id);
}

/** The choice made in this visit, kept in memory too: storage can be blocked in an in-app browser. */
let explicitChoice: string | null = null;

/** Loads the catalog first, then switches, so the page never shows keys or half of one language. */
export async function setLanguage(id: LocaleId, persist = false): Promise<void> {
  const catalog = await loadCatalog(id);
  // Persist first: the page recomputes its language from the stored choice when the store changes.
  if (persist) {
    explicitChoice = id;
    writeLocal(STORAGE_KEYS.language, id);
  }
  applyToDocument(id);
  languageStore.set({ locale: id, direction: directionOf(id), ready: true, t: makeTranslate(catalog, id) });
}

export function preferredLanguages(): readonly string[] {
  if (typeof navigator === 'undefined') return [];
  return navigator.languages.length > 0 ? navigator.languages : [navigator.language];
}

export function storedLanguage(): string | null {
  return explicitChoice ?? readLocal(STORAGE_KEYS.language);
}

/** The language before any professional is known: stored choice, then the browser's, then English. */
export function initialLanguage(): LocaleId {
  return chooseLocale({ stored: storedLanguage(), preferred: preferredLanguages(), offered: [], fallback: DEFAULT_LOCALE });
}

/** The language for a professional's page (docs/07 section 7): the languages she offers decide. */
export function languageForPage(offered: readonly LocaleId[], fallback: LocaleId): LocaleId {
  return chooseLocale({ stored: storedLanguage(), preferred: preferredLanguages(), offered, fallback });
}

export function useI18n(): LanguageState {
  return useStore(languageStore);
}

export function useT(): Translate {
  return useStore(languageStore).t;
}
