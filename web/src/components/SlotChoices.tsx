// The times of one day with the smart slots of D56: the suggested times first (the ones that keep her day compact)
// and a quiet "Show all times" link that reveals the other free times in place. Every time in either list can be
// booked; nothing is hidden when she keeps her day open. The parent gives it a `key` per day, so the link closes again
// on another day.

import type { JSX } from 'preact';
import { useState } from 'preact/hooks';

import type { Formatter } from '../lib/format';
import { useT } from '../i18n';
import { SlotList } from './Calendar';

interface SlotChoicesProps {
  readonly slots: readonly string[];
  readonly more: readonly string[];
  readonly selected: string | null;
  readonly formatter: Formatter;
  readonly onSelect: (slot: string) => void;
  readonly label: string;
  readonly taken?: ReadonlySet<string>;
}

export function SlotChoices({ slots, more, selected, formatter, onSelect, label, taken }: SlotChoicesProps): JSX.Element {
  const t = useT();
  const [open, setOpen] = useState(false);
  // A time she already picked from the hidden ones stays visible when she comes back to the step.
  const showsAll = open || (selected !== null && more.includes(selected));
  const shown = showsAll ? [...slots, ...more].sort() : slots;
  return (
    <div class="stack-sm">
      <SlotList slots={shown} selected={selected} formatter={formatter} onSelect={onSelect} label={label} taken={taken} />
      {!showsAll && more.length > 0 ? (
        <button type="button" class="link-button slots-more" data-testid="show-all-times" onClick={() => { setOpen(true); }}>
          {t('bk4.showAll')}
        </button>
      ) : null}
    </div>
  );
}
