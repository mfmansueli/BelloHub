// Everything a page prints that comes from a number, a date or a list goes through here, with `Intl` only
// (docs/07-LOCALIZATION.md sections 2.4 and 7). Dates and times use the reader's language in the PROFESSIONAL's
// time zone; money uses the business currency; the week start and the clock follow the business region (D25).

import type { LocaleId } from './locales';
import { parseDateKey, regionClock, type DateKey, type RegionClock } from './datetime';

export interface FormatContext {
  readonly localeId: LocaleId;
  /** Business region (ISO 3166-1 alpha-2), which sets the week start, the clock and the Arabic digit style. */
  readonly regionCode: string;
  /** Business IANA time zone. */
  readonly timeZone: string;
  /** Business currency (ISO 4217). */
  readonly currency: string;
  /** Her override of the week start (0 = Sunday), `LocalePrefs.weekStart`; the region decides when absent. */
  readonly weekStart?: number;
  /** Her override of the clock, `LocalePrefs.use24Hour`; the region decides when absent. */
  readonly use24Hour?: boolean;
}

/**
 * The BCP 47 tag handed to `Intl`. Arabic keeps the digit style of the business region (Saudi Arabia shows
 * Arabic-Indic digits, the Emirates Western digits); every other language uses its own tag.
 */
export function intlTag(localeId: LocaleId, regionCode: string): string {
  if (localeId === 'ar' && /^(SA|AE|EG|KW|QA|BH|OM|JO|LB|MA|DZ|TN)$/.test(regionCode.toUpperCase())) {
    return `ar-${regionCode.toUpperCase()}`;
  }
  return localeId;
}

export class Formatter {
  readonly tag: string;
  readonly clock: RegionClock;
  private readonly cache = new Map<string, Intl.DateTimeFormat>();

  constructor(readonly context: FormatContext) {
    this.tag = intlTag(context.localeId, context.regionCode);
    const region = regionClock(context.regionCode);
    this.clock = {
      firstDay: context.weekStart ?? region.firstDay,
      hourCycle: context.use24Hour === undefined ? region.hourCycle : context.use24Hour ? 'h23' : 'h12',
    };
  }

  get timeZone(): string {
    return this.context.timeZone;
  }

  private dateFormat(key: string, options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
    let format = this.cache.get(key);
    if (format === undefined) {
      format = new Intl.DateTimeFormat(this.tag, { timeZone: this.context.timeZone, ...options });
      this.cache.set(key, format);
    }
    return format;
  }

  /** Civil dates (a calendar cell) have no zone: format them as UTC so the day cannot move. */
  private civilFormat(key: string, options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
    let format = this.cache.get(key);
    if (format === undefined) {
      format = new Intl.DateTimeFormat(this.tag, { timeZone: 'UTC', ...options });
      this.cache.set(key, format);
    }
    return format;
  }

  /** `15:00` (or `3:00 PM` where the business region uses 12 hours). */
  time(instant: number | string): string {
    return this.dateFormat('time', { hour: 'numeric', minute: '2-digit', hourCycle: this.clock.hourCycle }).format(
      toMs(instant),
    );
  }

  /** The same instant on the device clock, for "that is 19:00 where you are". */
  timeOnDevice(instant: number | string): string {
    return new Intl.DateTimeFormat(this.tag, {
      hour: 'numeric',
      minute: '2-digit',
      hourCycle: this.clock.hourCycle,
    }).format(toMs(instant));
  }

  private monthDay(format: 'long' | 'short', instant: number): string {
    return this.dateFormat(`md-${format}`, { month: format, day: 'numeric' }).format(instant);
  }

  /** `Thursday · October 1` */
  weekdayDate(instant: number | string): string {
    const ms = toMs(instant);
    const weekday = this.dateFormat('wd-long', { weekday: 'long' }).format(ms);
    return `${weekday} · ${this.monthDay('long', ms)}`;
  }

  /** `Thu, Oct 1` */
  shortDate(instant: number | string): string {
    return this.dateFormat('short', { weekday: 'short', month: 'short', day: 'numeric' }).format(toMs(instant));
  }

  /** `Thursday, October 1` */
  longDate(instant: number | string): string {
    return this.dateFormat('long', { weekday: 'long', month: 'long', day: 'numeric' }).format(toMs(instant));
  }

  /** `October 1` */
  dayMonth(instant: number | string): string {
    return this.monthDay('long', toMs(instant));
  }

  /** `Thursday, October 1` for a civil date. */
  longDateOf(key: DateKey): string {
    const { year, month, day } = parseDateKey(key);
    return this.civilFormat('c-long', { weekday: 'long', month: 'long', day: 'numeric' }).format(
      Date.UTC(year, month - 1, day, 12),
    );
  }

  /** `Thu` for a civil date (the day chips of the rebook and reschedule pages). */
  weekdayShortOf(key: DateKey): string {
    const { year, month, day } = parseDateKey(key);
    return this.civilFormat('c-wd-short', { weekday: 'short' }).format(Date.UTC(year, month - 1, day, 12));
  }

  /** `October 2026` */
  monthYear(year: number, month: number): string {
    return this.civilFormat('c-my', { month: 'long', year: 'numeric' }).format(Date.UTC(year, month - 1, 1, 12));
  }

  /** Narrow weekday letters starting on `firstDay` (0 = Sunday), for the calendar header. */
  weekdayHeaders(firstDay: number, style: 'narrow' | 'short' = 'narrow'): { label: string; full: string }[] {
    const narrow = this.civilFormat(`wd-${style}`, { weekday: style });
    const full = this.civilFormat('wd-full', { weekday: 'long' });
    // 2024-01-07 was a Sunday.
    return Array.from({ length: 7 }, (_, i) => {
      const at = Date.UTC(2024, 0, 7 + ((firstDay + i) % 7), 12);
      return { label: narrow.format(at), full: full.format(at) };
    });
  }

  number(value: number): string {
    return new Intl.NumberFormat(this.tag).format(value);
  }

  /** `90 min` (the unit short form of the language). */
  minutes(value: number): string {
    try {
      return new Intl.NumberFormat(this.tag, { style: 'unit', unit: 'minute', unitDisplay: 'short' }).format(value);
    } catch {
      return `${this.number(value)} min`;
    }
  }

  /** `R$70`, `R$70,50`, `€14,99`: whole amounts have no decimals, like the prototype. */
  money(amount: number, currency: string = this.context.currency): string {
    const whole = Number.isInteger(amount);
    return new Intl.NumberFormat(this.tag, {
      style: 'currency',
      currency,
      minimumFractionDigits: whole ? 0 : 2,
      maximumFractionDigits: whole ? 0 : 2,
    }).format(amount);
  }

  /** `0:24`, with the digits of the language. */
  countdown(totalSeconds: number): string {
    const seconds = Math.max(0, Math.floor(totalSeconds));
    const minutes = Math.floor(seconds / 60);
    const rest = new Intl.NumberFormat(this.tag, { minimumIntegerDigits: 2, useGrouping: false }).format(seconds % 60);
    return `${new Intl.NumberFormat(this.tag, { useGrouping: false }).format(minutes)}:${rest}`;
  }

  /** `A, B and C` in the language's own list style. */
  list(items: readonly string[]): string {
    try {
      return new Intl.ListFormat(this.tag, { style: 'long', type: 'conjunction' }).format(items);
    } catch {
      return items.join(', ');
    }
  }

  pluralCategory(count: number): Intl.LDMLPluralRule {
    return new Intl.PluralRules(this.tag).select(count);
  }
}

function toMs(instant: number | string): number {
  return typeof instant === 'number' ? instant : Date.parse(instant);
}
