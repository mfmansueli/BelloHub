// Choices built on native inputs (radio, checkbox), so the keyboard, focus and screen readers work without extra code.

import type { ComponentChildren, JSX } from 'preact';

import { Icon } from './Icon';

interface OptionProps {
  readonly type: 'radio' | 'checkbox';
  readonly name: string;
  readonly value: string;
  readonly checked: boolean;
  readonly onChange: (checked: boolean) => void;
  readonly title: string;
  readonly detail?: string;
  readonly price?: string | undefined;
  readonly testId?: string;
}

/** A card that is a radio or a checkbox: a service, an add-on, a reason. */
export function Option({ type, name, value, checked, onChange, title, detail, price, testId }: OptionProps): JSX.Element {
  return (
    <label class="option">
      <input
        type={type}
        name={name}
        value={value}
        checked={checked}
        data-testid={testId}
        onChange={(event) => {
          onChange(event.currentTarget.checked);
        }}
      />
      <span class="mark" aria-hidden="true">
        {type === 'checkbox' ? <Icon name="check" /> : null}
      </span>
      <span class="body">
        <b>{title}</b>
        {detail === undefined ? null : <span>{detail}</span>}
      </span>
      {price === undefined || price === '' ? null : <span class="price">{price}</span>}
    </label>
  );
}

interface ChipProps {
  readonly pressed: boolean;
  readonly onToggle: () => void;
  readonly children: ComponentChildren;
  readonly testId?: string;
}

/** A toggle chip. `aria-pressed` carries the state; the fill is only the visual. */
export function Chip({ pressed, onToggle, children, testId }: ChipProps): JSX.Element {
  return (
    <button type="button" class="chip" aria-pressed={pressed ? 'true' : 'false'} data-testid={testId} onClick={onToggle}>
      {children}
    </button>
  );
}

interface SegmentedProps<T extends string> {
  readonly name: string;
  readonly legend: string;
  readonly value: T | null;
  readonly options: readonly { readonly value: T; readonly label: string }[];
  readonly onChange: (value: T) => void;
  readonly testId?: string;
}

/** Two or three exclusive choices (Yes / No) as radios in a fieldset. */
export function Segmented<T extends string>({ name, legend, value, options, onChange, testId }: SegmentedProps<T>): JSX.Element {
  return (
    <fieldset>
      <legend class="sr-only">{legend}</legend>
      <div class="segmented">
        {options.map((option) => (
          <label key={option.value}>
            <input
              type="radio"
              name={name}
              value={option.value}
              checked={value === option.value}
              data-testid={testId === undefined ? undefined : `${testId}-${option.value}`}
              onChange={() => {
                onChange(option.value);
              }}
            />
            <span>{option.label}</span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}
