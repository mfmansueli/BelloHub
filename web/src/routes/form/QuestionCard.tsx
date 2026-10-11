// One question of the professional's health form, from her published template. Four kinds: yes/no, one of several,
// several of several, and free text. Labels come in the page language when she wrote them in it. The free text and
// every choice stay in the component's state (docs/10 section 5): no storage, no URL, no log.

import type { JSX } from 'preact';

import type { FormQuestion } from '../../api/types';
import type { AnswerValue } from '../../crypto/envelope';
import { Chip, Segmented } from '../../components/Choices';
import { TextArea } from '../../components/Field';
import { Icon } from '../../components/Icon';
import { useI18n } from '../../i18n';
import { pickLocalized, type LocaleId } from '../../lib/locales';
import { langAttribute } from '../../lib/text';
import { isAnswered, toggleChoice } from './payload';

interface Props {
  readonly question: FormQuestion;
  readonly value: AnswerValue | undefined;
  readonly onChange: (value: AnswerValue | undefined) => void;
  readonly pageDefault: LocaleId;
  readonly showError: boolean;
}

export function QuestionCard({ question, value, onChange, pageDefault, showError }: Props): JSX.Element {
  const { t, locale } = useI18n();
  const label = pickLocalized(question.label, locale, pageDefault);
  const hint = pickLocalized(question.hint, locale, pageDefault);
  const labelId = `q-${question.key}`;
  const missing = showError && question.required === true && !isAnswered(value);
  const optionLabel = (option: { label: FormQuestion['label'] }): { text: string; lang: string | undefined } => {
    const picked = pickLocalized(option.label, locale, pageDefault);
    return { text: picked?.text ?? '', lang: langAttribute(picked, locale) };
  };

  return (
    <fieldset class="question" data-field={labelId} tabIndex={-1} id={labelId} data-testid={`question-${question.key}`}>
      <legend class="label" lang={langAttribute(label, locale)}>
        {label?.text ?? question.key}
        {question.required === true ? null : <span class="optional"> · {t('common.optional')}</span>}
      </legend>
      {hint === null ? null : (
        <span class="hint" lang={langAttribute(hint, locale)}>
          {hint.text}
        </span>
      )}

      {question.kind === 'yesNo' ? (
        <Segmented
          name={labelId}
          legend={label?.text ?? question.key}
          value={typeof value === 'boolean' ? (value ? 'yes' : 'no') : null}
          options={[
            { value: 'yes', label: t('common.yes') },
            { value: 'no', label: t('common.no') },
          ]}
          onChange={(next) => { onChange(next === 'yes'); }}
          testId={`answer-${question.key}`}
        />
      ) : null}

      {question.kind === 'choice' ? (
        <div class="chips" role="group" aria-label={label?.text ?? question.key}>
          {(question.options ?? []).map((option) => (
            <Chip key={option.value} pressed={value === option.value} testId={`answer-${question.key}-${option.value}`} onToggle={() => { onChange(value === option.value ? undefined : option.value); }}>
              <span lang={optionLabel(option).lang}>{optionLabel(option).text}</span>
            </Chip>
          ))}
        </div>
      ) : null}

      {question.kind === 'multiChoice' ? (
        <div class="chips" role="group" aria-label={label?.text ?? question.key}>
          {(question.options ?? []).map((option) => {
            const chosen = Array.isArray(value) && (value as readonly string[]).includes(option.value);
            return (
              <Chip
                key={option.value}
                pressed={chosen}
                testId={`answer-${question.key}-${option.value}`}
                onToggle={() => {
                  const next = toggleChoice(Array.isArray(value) ? (value as readonly string[]) : [], option.value);
                  onChange(next.length === 0 ? undefined : next);
                }}
              >
                <span lang={optionLabel(option).lang}>{optionLabel(option).text}</span>
              </Chip>
            );
          })}
        </div>
      ) : null}

      {question.kind === 'text' ? (
        <TextArea
          label={label?.text ?? question.key}
          value={typeof value === 'string' ? value : ''}
          onInput={(text) => { onChange(text === '' ? undefined : text); }}
          placeholder={t('cl4.writeHere')}
          sensitive
          labelHidden
          rows={3}
          testId={`answer-${question.key}`}
        />
      ) : null}

      {missing ? (
        <p class="field-error" role="alert">
          <Icon name="alert" />
          <span>{t('cl4.err.required')}</span>
        </p>
      ) : null}
    </fieldset>
  );
}
