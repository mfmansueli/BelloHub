// What every screen below a professional's page needs to know: who she is (name, zone, currency, WhatsApp) and how
// to format a time, a date or a price for her page. Provided once by the layout of a route, read with hooks.

import { createContext, type ComponentChildren, type JSX } from 'preact';
import { useContext, useMemo } from 'preact/hooks';

import type { ProfessionalLite } from '../api/types';
import { deviceTimeZone } from '../lib/datetime';
import { Formatter } from '../lib/format';
import { useI18n } from '../i18n';
import type { LocaleId } from '../lib/locales';

const ProfessionalContext = createContext<ProfessionalLite | null>(null);
const FormatterContext = createContext<Formatter | null>(null);

export function formatterFor(professional: ProfessionalLite, locale: LocaleId): Formatter {
  return new Formatter({
    localeId: locale,
    regionCode: professional.regionCode,
    timeZone: professional.timeZoneID,
    currency: professional.currencyCode,
  });
}

const LOCALE_REGIONS: Readonly<Record<LocaleId, string>> = {
  'pt-BR': 'BR', 'pt-PT': 'PT', 'es-MX': 'MX', 'es-419': 'AR', es: 'ES', en: 'US', 'en-GB': 'GB',
  it: 'IT', fr: 'FR', de: 'DE', tr: 'TR', id: 'ID', hi: 'IN', ar: 'SA',
};

/** A formatter for pages with no professional (landing, privacy): the device's zone and the language's own region. */
export function neutralFormatter(locale: LocaleId): Formatter {
  return new Formatter({ localeId: locale, regionCode: LOCALE_REGIONS[locale], timeZone: deviceTimeZone() ?? 'UTC', currency: 'USD' });
}

export function ProfessionalProvider({ professional, children }: { professional: ProfessionalLite; children: ComponentChildren }): JSX.Element {
  const { locale } = useI18n();
  const formatter = useMemo(() => formatterFor(professional, locale), [professional, locale]);
  return (
    <ProfessionalContext.Provider value={professional}>
      <FormatterContext.Provider value={formatter}>{children}</FormatterContext.Provider>
    </ProfessionalContext.Provider>
  );
}

export function useProfessional(): ProfessionalLite {
  const professional = useContext(ProfessionalContext);
  if (professional === null) throw new Error('no professional in scope');
  return professional;
}

export function useOptionalProfessional(): ProfessionalLite | null {
  return useContext(ProfessionalContext);
}

export function useFormatter(): Formatter {
  const formatter = useContext(FormatterContext);
  const { locale } = useI18n();
  return useMemo(() => formatter ?? neutralFormatter(locale), [formatter, locale]);
}
