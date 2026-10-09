// Form fields. Labels are real <label>s, errors are tied to their field with aria-describedby and announced, and
// the digits a person types in any script are normalized to ASCII as she types (docs/07 section 7).

import type { JSX } from 'preact';
import { useId, useMemo } from 'preact/hooks';

import { COUNTRIES, countryName } from '../lib/countries';
import { toAsciiDigits } from '../lib/digits';
import { REGION_PRESETS } from '../lib/regions.generated';
import { useI18n, useT } from '../i18n';
import { Icon } from './Icon';

interface FieldFrameProps {
  readonly id: string;
  readonly label: string;
  /** Keep the label for assistive technology but do not show it (the question around it already says it). */
  readonly labelHidden?: boolean;
  readonly optional?: boolean;
  readonly error?: string | undefined;
  readonly hint?: string | undefined;
  readonly children: JSX.Element;
}

function FieldFrame({ id, label, labelHidden = false, optional = false, error, hint, children }: FieldFrameProps): JSX.Element {
  const t = useT();
  return (
    <div class="field">
      <label for={id} class={labelHidden ? 'sr-only' : undefined}>
        {label}
        {optional ? <span class="optional"> · {t('common.optional')}</span> : null}
      </label>
      {children}
      {hint === undefined ? null : (
        <p class="field-hint" id={`${id}-hint`}>
          {hint}
        </p>
      )}
      {error === undefined ? null : (
        <p class="field-error" id={`${id}-error`} role="alert">
          <Icon name="alert" />
          <span>{error}</span>
        </p>
      )}
    </div>
  );
}

function describedBy(id: string, error: string | undefined, hint: string | undefined): string | undefined {
  const ids = [hint === undefined ? '' : `${id}-hint`, error === undefined ? '' : `${id}-error`].filter(Boolean);
  return ids.length === 0 ? undefined : ids.join(' ');
}

interface TextFieldProps {
  readonly label: string;
  readonly value: string;
  readonly onInput: (value: string) => void;
  readonly type?: 'text' | 'email' | 'tel';
  readonly inputMode?: 'text' | 'email' | 'tel' | 'numeric';
  readonly autoComplete?: string;
  readonly placeholder?: string;
  readonly optional?: boolean;
  readonly error?: string | undefined;
  readonly hint?: string | undefined;
  readonly maxLength?: number;
  /** A clinical or personal field: no autofill, no spellcheck, no suggestions sent to third parties (docs/10 section 5). */
  readonly sensitive?: boolean;
  readonly testId?: string;
  readonly id?: string;
  readonly dir?: 'ltr' | 'rtl' | 'auto';
}

export function TextField({ label, value, onInput, type = 'text', inputMode, autoComplete, placeholder, optional, error, hint, maxLength, sensitive = false, testId, id: given, dir }: TextFieldProps): JSX.Element {
  const generated = useId();
  const id = given ?? generated;
  return (
    <FieldFrame id={id} label={label} optional={optional ?? false} error={error} hint={hint}>
      <input
        id={id}
        class="input"
        type={type}
        value={value}
        inputMode={inputMode}
        autoComplete={sensitive ? 'off' : autoComplete}
        autoCapitalize={sensitive ? 'off' : undefined}
        autoCorrect={sensitive ? 'off' : undefined}
        spellcheck={sensitive ? false : undefined}
        placeholder={placeholder}
        maxLength={maxLength}
        aria-invalid={error === undefined ? undefined : 'true'}
        aria-describedby={describedBy(id, error, hint)}
        data-testid={testId}
        dir={dir}
        onInput={(event) => {
          onInput(event.currentTarget.value);
        }}
      />
    </FieldFrame>
  );
}

interface TextAreaProps {
  readonly label: string;
  readonly labelHidden?: boolean;
  readonly value: string;
  readonly onInput: (value: string) => void;
  readonly placeholder?: string;
  readonly optional?: boolean;
  readonly error?: string | undefined;
  readonly hint?: string | undefined;
  readonly maxLength?: number;
  readonly sensitive?: boolean;
  readonly testId?: string;
  readonly rows?: number;
}

export function TextArea({ label, labelHidden, value, onInput, placeholder, optional, error, hint, maxLength, sensitive = false, testId, rows = 4 }: TextAreaProps): JSX.Element {
  const id = useId();
  return (
    <FieldFrame id={id} label={label} labelHidden={labelHidden ?? false} optional={optional ?? false} error={error} hint={hint}>
      <textarea
        id={id}
        class="textarea"
        rows={rows}
        value={value}
        placeholder={placeholder}
        maxLength={maxLength}
        autoComplete={sensitive ? 'off' : undefined}
        autoCapitalize={sensitive ? 'off' : undefined}
        autoCorrect={sensitive ? 'off' : undefined}
        spellcheck={sensitive ? false : undefined}
        aria-invalid={error === undefined ? undefined : 'true'}
        aria-describedby={describedBy(id, error, hint)}
        data-testid={testId}
        onInput={(event) => {
          onInput(event.currentTarget.value);
        }}
      />
    </FieldFrame>
  );
}

interface CodeFieldProps {
  readonly label: string;
  readonly value: string;
  readonly onInput: (value: string) => void;
  readonly error?: string | undefined;
  readonly length?: number;
  readonly testId?: string;
}

/** A one-time code: numeric keyboard, autofill from the SMS, any digit system accepted and turned into ASCII. */
export function CodeField({ label, value, onInput, error, length = 6, testId = 'code' }: CodeFieldProps): JSX.Element {
  const id = useId();
  return (
    <FieldFrame id={id} label={label} error={error} hint={undefined}>
      <input
        id={id}
        class="input input-code"
        type="text"
        inputMode="numeric"
        autoComplete="one-time-code"
        maxLength={length * 2}
        value={value}
        aria-invalid={error === undefined ? undefined : 'true'}
        aria-describedby={describedBy(id, error, undefined)}
        data-testid={testId}
        onInput={(event) => {
          onInput(toAsciiDigits(event.currentTarget.value).replace(/\D/g, '').slice(0, length));
        }}
      />
    </FieldFrame>
  );
}

interface PhoneFieldProps {
  readonly label: string;
  readonly countryLabel: string;
  readonly country: string;
  readonly input: string;
  readonly onChange: (country: string, input: string) => void;
  readonly defaultCountry: string;
  readonly error?: string | undefined;
  readonly testId?: string;
}

/** A country picker (the presets first, then every country) beside a number field that accepts any digit system. */
export function PhoneField({ label, countryLabel, country, input, onChange, defaultCountry, error, testId = 'phone' }: PhoneFieldProps): JSX.Element {
  const { locale } = useI18n();
  const id = useId();
  const options = useMemo(() => {
    const collator = new Intl.Collator(locale);
    const presetCodes = REGION_PRESETS.map((preset) => preset.code);
    const first = [defaultCountry, ...presetCodes.filter((code) => code !== defaultCountry)];
    const rest = COUNTRIES.map((c) => c.code).filter((code) => !first.includes(code));
    const name = (code: string): string => countryName(code, locale);
    rest.sort((a, b) => collator.compare(name(a), name(b)));
    return [...first, ...rest].flatMap((code) => {
      const found = COUNTRIES.find((c) => c.code === code);
      return found === undefined ? [] : [{ code, text: `${name(code)} (+${found.callingCode})` }];
    });
  }, [locale, defaultCountry]);
  return (
    <div class="field">
      <span class="label" id={`${id}-label`}>
        {label}
      </span>
      <div class="input-phone" role="group" aria-labelledby={`${id}-label`}>
        <select
          class="select"
          aria-label={countryLabel}
          value={country}
          data-testid={`${testId}-country`}
          onChange={(event) => {
            onChange(event.currentTarget.value, input);
          }}
        >
          {options.map((option) => (
            <option key={option.code} value={option.code}>
              {option.text}
            </option>
          ))}
        </select>
        <input
          id={id}
          class="input"
          type="tel"
          inputMode="tel"
          autoComplete="tel-national"
          value={input}
          aria-labelledby={`${id}-label`}
          aria-invalid={error === undefined ? undefined : 'true'}
          aria-describedby={describedBy(id, error, undefined)}
          data-testid={testId}
          dir="ltr"
          onInput={(event) => {
            onChange(country, toAsciiDigits(event.currentTarget.value));
          }}
        />
      </div>
      {error === undefined ? null : (
        <p class="field-error" id={`${id}-error`} role="alert">
          <Icon name="alert" />
          <span>{error}</span>
        </p>
      )}
    </div>
  );
}
