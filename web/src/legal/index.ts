// The legal texts the pages show, embedded at build time by scripts/build-legal.ts from legal/<document>/<localization>/.
// One small JSON per document and localization, loaded when a page needs it. Only notices live here (how the booking
// is used, how to ask for a copy or deletion, Bello Hub's own privacy policy); no consent text of any kind (D55).

import { useEffect, useState } from 'preact/hooks';

import { useI18n } from '../i18n';
import type { LocaleId } from '../lib/locales';

export type LegalDocument = 'client-notice' | 'data-requests' | 'privacy-policy';

export type Inline = { k: 't'; v: string } | { k: 'b'; v: string } | { k: 'a'; v: string } | { k: 'pro' };

export type Block =
  | { type: 'h1'; text: Inline[] }
  | { type: 'p'; text: Inline[] }
  | { type: 'ul'; items: Inline[][] };

export interface LegalFile {
  /** The version of the text (the file name under legal/). Nothing is signed on the web (D55): it is informative. */
  readonly version: string;
  readonly blocks: readonly Block[];
}

const loaders = import.meta.glob<{ default: LegalFile }>('./generated/*/*.json');

export async function loadLegal(document: LegalDocument, locale: LocaleId): Promise<LegalFile> {
  const loader = loaders[`./generated/${document}/${locale}.json`] ?? loaders[`./generated/${document}/en.json`];
  if (loader === undefined) throw new Error('legal text missing');
  return (await loader()).default;
}

export type LegalState = { readonly status: 'loading' } | { readonly status: 'error' } | { readonly status: 'ready'; readonly file: LegalFile };

/** The text of a document in the page language (and the language it was written in). */
export function useLegal(document: LegalDocument, enabled = true): LegalState {
  const { locale } = useI18n();
  const [state, setState] = useState<LegalState>({ status: 'loading' });
  useEffect(() => {
    if (!enabled) return;
    let current = true;
    setState({ status: 'loading' });
    loadLegal(document, locale).then(
      (file) => {
        if (current) setState({ status: 'ready', file });
      },
      () => {
        if (current) setState({ status: 'error' });
      },
    );
    return () => {
      current = false;
    };
  }, [document, locale, enabled]);
  return state;
}
