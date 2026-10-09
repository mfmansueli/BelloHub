// The free start times of one day: availability minus visits, breaks, days off, blocks and the buffer, in the
// professional's time zone, correct on daylight-saving change days. A line-by-line mirror of the iOS
// `FreeSlotsCalculator` (BelloHub/Models/Agenda/FreeSlotsCalculator.swift). The shared fixture
// test/fixtures/rules.fixture.json is produced by running the Swift code, so drift fails a test.

import type { LocalDate } from './time.js';
import { addDays, instantAtLocal, localDateOf, weekdayOf } from './time.js';

/** A half-open stretch of real time, in milliseconds since the epoch. */
export interface Interval {
  start: number;
  end: number;
}

export interface WeeklyRule {
  /** 1 is Sunday ... 7 is Saturday. */
  weekday: number;
  startMinutes: number;
  endMinutes: number;
}

export interface BreakRule {
  /** Undefined means every day. */
  weekday?: number | undefined;
  startMinutes: number;
  endMinutes: number;
}

export interface DayOffRange {
  startDate: LocalDate;
  endDate: LocalDate;
}

export interface AvailabilitySettings {
  weekly: WeeklyRule[];
  breaks: BreakRule[];
  daysOff: DayOffRange[];
  bufferMinutes: number;
  minNoticeHours: number;
  maxDaysAhead: number;
  timeZoneID: string;
}

export interface FreeSlotsRequest {
  /** The local day to look at, in the business time zone. */
  day: LocalDate;
  durationMinutes: number;
  now: number;
  settings: AvailabilitySettings;
  /** Visits already booked (and soft holds). A buffer is kept between them and a new visit. */
  appointments: Interval[];
  /** Closed stretches. No buffer is added around them. */
  blocks: Interval[];
  /** Start times are offered on this grid from the start of each working stretch. */
  stepMinutes: number;
}

/** The grid of offered start times, in minutes (docs/10: the same on the web and in the app). */
export const SLOT_STEP_MINUTES = 15;

const MINUTE_MS = 60_000;
const HOUR_MS = 3_600_000;

export function freeSlots(request: FreeSlotsRequest): number[] {
  const { settings } = request;
  const zone = settings.timeZoneID;
  if (!isBookableDay(request)) return [];

  const weekday = weekdayOf(request.day);
  const breaks = settings.breaks
    .filter((rule) => rule.weekday === undefined || rule.weekday === weekday)
    .map((rule) => interval(request.day, rule.startMinutes, rule.endMinutes, zone))
    .filter((value): value is Interval => value !== null);
  const buffer = settings.bufferMinutes * MINUTE_MS;
  const earliest = request.now + settings.minNoticeHours * HOUR_MS;
  const duration = request.durationMinutes * MINUTE_MS;
  const step = Math.max(request.stepMinutes, 1) * MINUTE_MS;

  const starts = new Set<number>();
  for (const rule of settings.weekly) {
    if (rule.weekday !== weekday) continue;
    const window = interval(request.day, rule.startMinutes, rule.endMinutes, zone);
    if (!window) continue;
    for (let start = window.start; start + duration <= window.end; start += step) {
      const candidate: Interval = { start, end: start + duration };
      if (start >= earliest && fits(candidate, breaks, request.appointments, request.blocks, buffer)) {
        starts.add(start);
      }
    }
  }
  return [...starts].sort((a, b) => a - b);
}

function isBookableDay(request: FreeSlotsRequest): boolean {
  const { settings } = request;
  const today = localDateOf(request.now, settings.timeZoneID);
  const last = addDays(today, settings.maxDaysAhead);
  if (request.day < today || request.day > last) return false;
  return !settings.daysOff.some((off) => request.day >= off.startDate && request.day <= off.endDate);
}

/** The real-time stretch of a local wall-clock stretch; null when empty or reversed. */
function interval(day: LocalDate, startMinutes: number, endMinutes: number, zone: string): Interval | null {
  const start = instantAtLocal(day, startMinutes, zone);
  const end = instantAtLocal(day, endMinutes, zone);
  return end > start ? { start, end } : null;
}

function fits(
  candidate: Interval,
  breaks: Interval[],
  appointments: Interval[],
  blocks: Interval[],
  buffer: number
): boolean {
  if ([...breaks, ...blocks].some((closed) => overlaps(candidate, closed, 0))) return false;
  return !appointments.some((visit) => overlaps(candidate, visit, buffer));
}

/** Two stretches overlap if the gap between them is smaller than `margin`. */
export function overlaps(first: Interval, second: Interval, margin: number): boolean {
  return first.start < second.end + margin && first.end + margin > second.start;
}
