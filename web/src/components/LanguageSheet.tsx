// The language chooser (docs/07 section 7): only the languages she offers, each in its own name, the choice kept
// in localStorage (the one thing the page stores), and the whole page switching at once.

import type { JSX } from 'preact';
import { useState } from 'preact/hooks';

import { setLanguage, useI18n } from '../i18n';
import { AUTONYMS, LOCALE_IDS, shortLabel, type LocaleId } from '../lib/locales';
import { Icon } from './Icon';
import { Sheet } from './Sheet';

export function LanguageChooser({ offered }: { offered: readonly LocaleId[] }): JSX.Element | null {
  const { t, locale } = useI18n();
  const [open, setOpen] = useState(false);
  const choices = offered.length > 0 ? offered : LOCALE_IDS;
  if (choices.length < 2) return null;
  return (
    <>
      <div class="lang-row">
        <button type="button" class="lang-button" onClick={() => { setOpen(true); }} aria-label={t('lang.title')} aria-haspopup="dialog" data-testid="lang-open">
          <Icon name="globe" />
          <span class="ltr">{shortLabel(locale)}</span>
        </button>
      </div>
      <Sheet open={open} onClose={() => { setOpen(false); }} title={t('lang.title')} testId="lang-sheet">
        <p class="meta">{t('lang.hint')}</p>
        <ul class="sheet-list">
          {choices.map((id) => (
            <li key={id}>
              <button
                type="button"
                class="sheet-row"
                lang={id}
                aria-pressed={id === locale ? 'true' : 'false'}
                data-testid={`lang-${id}`}
                onClick={() => {
                  void setLanguage(id, true).then(() => { setOpen(false); });
                }}
              >
                <span class="grow">{AUTONYMS[id]}</span>
                {id === locale ? <Icon name="check" /> : null}
              </button>
            </li>
          ))}
        </ul>
      </Sheet>
    </>
  );
}
