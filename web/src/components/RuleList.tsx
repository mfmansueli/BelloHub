// "Maria's rules": the lines her app generated from her policy, published once per localization so the iPhone and
// the web can never disagree (docs/07 section 7). Shown as published; the page only picks the right language.

import type { JSX } from 'preact';

import type { ProfessionalLite, RuleLine } from '../api/types';
import { useI18n } from '../i18n';
import { langAttribute, pickRules } from '../lib/text';
import { Icon } from './Icon';

export function useRules(
  rules: Readonly<Partial<Record<string, readonly RuleLine[]>>> | undefined,
  professional: ProfessionalLite,
): { lines: readonly RuleLine[]; lang: string | undefined } {
  const { locale } = useI18n();
  const picked = pickRules(rules, locale, professional.defaultLocale);
  return { lines: picked?.value ?? [], lang: langAttribute(picked, locale) };
}

export function RuleList({ lines, lang }: { lines: readonly RuleLine[]; lang: string | undefined }): JSX.Element | null {
  if (lines.length === 0) return null;
  return (
    <ul class="check-list" lang={lang} data-testid="rules">
      {lines.map((line, index) => (
        <li key={index} data-kind={line.kind}>
          <Icon name="check" />
          <span>{line.text}</span>
        </li>
      ))}
    </ul>
  );
}
