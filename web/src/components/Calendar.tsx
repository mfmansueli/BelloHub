// The month calendar, the list of times of a day and the strip of days. Dates are civil dates in the professional's
// time zone; the week starts where her region (or she) says; arrows move between days like a date-picker grid.

import type { JSX } from 'preact';
import { useRef } from 'preact/hooks';

import { addDays, compareDateKeys, daysInMonth, monthGrid, toDateKey, type DateKey } from '../lib/datetime';
import type { Formatter } from '../lib/format';
import { useT } from '../i18n';
import { IconButton } from './Button';
import { Icon } from './Icon';

interface CalendarProps {
  readonly year: number;
  readonly month: number;
  readonly formatter: Formatter;
  readonly selected: DateKey | null;
  readonly today: DateKey;
  readonly isAvailable: (day: DateKey) => boolean;
  readonly onSelect: (day: DateKey) => void;
  /** Move the visible month by -1 or +1. */
  readonly onMonth: (delta: -1 | 1) => void;
  readonly canPrev: boolean;
  readonly canNext: boolean;
  /** Text shown beside the month name, such as "opens Oct 15". */
  readonly monthNote?: string | undefined;
}

export function Calendar({ year, month, formatter, selected, today, isAvailable, onSelect, onMonth, canPrev, canNext, monthNote }: CalendarProps): JSX.Element {
  const t = useT();
  const grid = useRef<HTMLDivElement>(null);
  const rows = monthGrid(year, month, formatter.clock.firstDay);
  const headers = formatter.weekdayHeaders(formatter.clock.firstDay);
  const key = (day: number): DateKey => toDateKey(year, month, day);
  // Roving tabindex: one stop in the grid, the selected day, else the first free one, else the first day.
  const firstFree = Array.from({ length: daysInMonth(year, month) }, (_, i) => i + 1).find((d) => isAvailable(key(d))) ?? 1;
  const stop = selected !== null && selected.startsWith(toDateKey(year, month, 1).slice(0, 8)) ? Number(selected.slice(8)) : firstFree;

  const focusDay = (day: DateKey): void => {
    grid.current?.querySelector<HTMLButtonElement>(`[data-day="${day}"]`)?.focus();
  };

  const onKeyDown = (event: KeyboardEvent, day: number): void => {
    const here = key(day);
    const move = (target: DateKey): void => {
      event.preventDefault();
      const prefix = toDateKey(year, month, 1).slice(0, 8);
      if (target.startsWith(prefix)) focusDay(target);
      else if (compareDateKeys(target, here) < 0 ? canPrev : canNext) {
        onMonth(compareDateKeys(target, here) < 0 ? -1 : 1);
        window.setTimeout(() => {
          focusDay(target);
        }, 0);
      }
    };
    switch (event.key) {
      case 'ArrowLeft':
        move(addDays(here, formatter.context.localeId === 'ar' ? 1 : -1));
        break;
      case 'ArrowRight':
        move(addDays(here, formatter.context.localeId === 'ar' ? -1 : 1));
        break;
      case 'ArrowUp':
        move(addDays(here, -7));
        break;
      case 'ArrowDown':
        move(addDays(here, 7));
        break;
      default:
    }
  };

  return (
    <div class="card calendar">
      <div class="cal-head">
        <h2 class="section" aria-live="polite">
          {formatter.monthYear(year, month)}
          {monthNote === undefined ? null : <span class="meta"> · {monthNote}</span>}
        </h2>
        <div class="cal-nav">
          <IconButton label={t('cal.prevMonth')} onClick={() => { onMonth(-1); }} disabled={!canPrev} testId="cal-prev">
            <Icon name="back" />
          </IconButton>
          <IconButton label={t('cal.nextMonth')} onClick={() => { onMonth(1); }} disabled={!canNext} testId="cal-next">
            <Icon name="chevron" />
          </IconButton>
        </div>
      </div>
      <div role="grid" aria-label={formatter.monthYear(year, month)} ref={grid}>
        <div role="row" class="cal-grid">
          {headers.map((header, index) => (
            <div key={index} role="columnheader" class="cal-dow" aria-label={header.full}>
              {header.label}
            </div>
          ))}
        </div>
        {rows.map((row, rowIndex) => (
          <div key={rowIndex} role="row" class="cal-grid">
            {row.map((day, cellIndex) => {
              if (day === null) return <div key={cellIndex} role="gridcell" />;
              const dayKey = key(day);
              const available = isAvailable(dayKey);
              const chosen = selected === dayKey;
              return (
                <div key={cellIndex} role="gridcell" aria-selected={chosen ? 'true' : undefined}>
                  <button
                    type="button"
                    class={`cal-day${dayKey === today ? ' today' : ''}`}
                    data-day={dayKey}
                    data-testid={`day-${dayKey}`}
                    aria-disabled={available ? undefined : 'true'}
                    aria-label={available ? formatter.longDateOf(dayKey) : t('cal.unavailable', { date: formatter.longDateOf(dayKey) })}
                    tabIndex={day === stop ? 0 : -1}
                    onKeyDown={(event) => {
                      onKeyDown(event, day);
                    }}
                    onClick={() => {
                      if (available) onSelect(dayKey);
                    }}
                  >
                    {formatter.number(day)}
                  </button>
                </div>
              );
            })}
          </div>
        ))}
      </div>
    </div>
  );
}

interface SlotListProps {
  readonly slots: readonly string[];
  readonly selected: string | null;
  readonly formatter: Formatter;
  readonly onSelect: (slot: string) => void;
  readonly label: string;
  /** Slots shown crossed out because they are taken (the reschedule page). */
  readonly taken?: ReadonlySet<string>;
}

export function SlotList({ slots, selected, formatter, onSelect, label, taken }: SlotListProps): JSX.Element {
  return (
    <div class="slots" role="group" aria-label={label}>
      {slots.map((slot) => {
        const isTaken = taken?.has(slot) === true;
        return (
          <button
            key={slot}
            type="button"
            class="slot"
            data-testid={`slot-${slot}`}
            aria-pressed={selected === slot ? 'true' : 'false'}
            aria-disabled={isTaken ? 'true' : undefined}
            onClick={() => {
              if (!isTaken) onSelect(slot);
            }}
          >
            <bdi>{formatter.time(slot)}</bdi>
          </button>
        );
      })}
    </div>
  );
}

interface DayStripProps {
  readonly days: readonly { readonly key: DateKey; readonly best?: boolean }[];
  readonly selected: DateKey | null;
  readonly formatter: Formatter;
  readonly onSelect: (day: DateKey) => void;
  readonly label: string;
  readonly bestLabel: string;
}

/** A row of days to pick from (rebook and reschedule). */
export function DayStrip({ days, selected, formatter, onSelect, label, bestLabel }: DayStripProps): JSX.Element {
  return (
    <div class="days" role="group" aria-label={label}>
      {days.map((day) => (
        <button
          key={day.key}
          type="button"
          class="day"
          data-testid={`day-${day.key}`}
          aria-pressed={selected === day.key ? 'true' : 'false'}
          aria-label={`${formatter.longDateOf(day.key)}${day.best === true ? `, ${bestLabel}` : ''}`}
          onClick={() => {
            onSelect(day.key);
          }}
        >
          <small>{formatter.weekdayShortOf(day.key)}</small>
          <span class="numeral">{formatter.number(Number(day.key.slice(8)))}</span>
          {day.best === true ? <small class="best">{bestLabel}</small> : <small aria-hidden="true">&nbsp;</small>}
        </button>
      ))}
    </div>
  );
}
