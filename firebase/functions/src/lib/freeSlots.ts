// The free start times of one day: availability minus visits, breaks, days off, blocks and the buffer, in the
// professional's time zone, correct on daylight-saving change days, with the smart slots of D56 (anchored starts,
// extra time and processing time, the compact-day ranking). A line-by-line mirror of the iOS `FreeSlotsCalculator`
// (BelloHub/Models/Agenda/FreeSlotsCalculator.swift). The shared fixture test/fixtures/rules.fixture.json is produced
// by running the Swift code, so drift fails a test.

import type { LocalDate } from './time.js';
import { addDays, instantAtLocal, localDateOf, weekdayOf } from './time.js';

/** A half-open stretch of real time, in milliseconds since the epoch. */
export interface Interval {
  start: number;
  end: number;
}

/**
 * The shape of a visit around and inside its visible stretch (D56). Prep and clean-up are blocked before and after it
 * and never shown to the client; processing is a stretch inside it, `processingStartMinutes` after it begins, while the
 * professional is free for another visit.
 */
export interface VisitTiming {
  prepMinutes: number;
  cleanupMinutes: number;
  processingStartMinutes: number;
  processingMinutes: number;
}

export const NO_EXTRA_TIME: VisitTiming = { prepMinutes: 0, cleanupMinutes: 0, processingStartMinutes: 0, processingMinutes: 0 };

/** A visit already booked (or held): its visible stretch and, when it has one, its shape. */
export interface TimedInterval extends Interval {
  timing?: VisitTiming | undefined;
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
  /** The visible length of the visit (service + add-ons + guests, D19). */
  durationMinutes: number;
  now: number;
  settings: AvailabilitySettings;
  /** Visits already booked (and soft holds). A buffer is kept between them and a new visit. */
  appointments: TimedInterval[];
  /** Closed stretches. No buffer is added around them. */
  blocks: Interval[];
  /** The grid of start times from the start of each working stretch; MATCH_SERVICE_STEP steps by the visit itself. */
  stepMinutes: number;
  /** The new visit's extra and processing time. */
  timing?: VisitTiming | undefined;
  /** "Keep my day compact": rank the starts that leave no dead gap first. */
  compact?: boolean | undefined;
  /** Her shortest published offer with its extra time (no buffer); a gap shorter than it plus the buffer is dead. */
  shortestOfferMinutes?: number | undefined;
}

/** Every free start, and the ones to show first (equal to `all` when the day is not kept compact). */
export interface SlotPlan {
  all: number[];
  recommended: number[];
}

/** The default grid of offered start times, in minutes (docs/10: the same on the web and in the app). */
export const SLOT_STEP_MINUTES = 15;
/** `slotStepMinutes` value meaning "match the service": step by the visit's footprint plus the buffer. */
export const MATCH_SERVICE_STEP = 0;
/** Anchored starts are rounded inwards to this clock, so a client never sees 10:17. */
export const ANCHOR_ROUNDING_MINUTES = 5;

const MINUTE_MS = 60_000;
const HOUR_MS = 3_600_000;

/** A stretch that holds her, with whether the buffer is kept at each edge (not at a processing edge, a break or a block). */
interface Segment {
  start: number;
  end: number;
  bufferedStart: boolean;
  bufferedEnd: boolean;
}

/** One free start and the gap it sits in, for the compact-day ranking. */
interface Placement {
  start: number;
  gap: string;
  deadMs: number;
  deadCount: number;
}

export function freeSlots(request: FreeSlotsRequest): number[] {
  return planSlots(request).all;
}

export function planSlots(request: FreeSlotsRequest): SlotPlan {
  const { settings } = request;
  const zone = settings.timeZoneID;
  if (!isBookableDay(request)) return { all: [], recommended: [] };

  const weekday = weekdayOf(request.day);
  const breaks = settings.breaks
    .filter((rule) => rule.weekday === undefined || rule.weekday === weekday)
    .map((rule) => interval(request.day, rule.startMinutes, rule.endMinutes, zone))
    .filter((value): value is Interval => value !== null);
  const buffer = settings.bufferMinutes * MINUTE_MS;
  const earliest = request.now + settings.minNoticeHours * HOUR_MS;
  const duration = request.durationMinutes * MINUTE_MS;
  const timing = request.timing ?? NO_EXTRA_TIME;
  const prep = Math.max(timing.prepMinutes, 0) * MINUTE_MS;
  const cleanup = Math.max(timing.cleanupMinutes, 0) * MINUTE_MS;
  const footprint = prep + duration + cleanup;
  const step = Math.max(request.stepMinutes > 0 ? request.stepMinutes * MINUTE_MS : footprint + buffer, MINUTE_MS);
  const closed: Segment[] = [...breaks, ...request.blocks].map((value) => ({
    start: value.start,
    end: value.end,
    bufferedStart: false,
    bufferedEnd: false
  }));
  const visits = request.appointments.flatMap((visit) => segmentsOf(visit.start, visit.end, visit.timing ?? NO_EXTRA_TIME));
  const obstacles = [...visits, ...closed];
  const shortest = Math.max(request.shortestOfferMinutes ?? 0, 0) * MINUTE_MS;
  const ranked = request.compact === true && shortest > 0;

  const all = new Set<number>();
  const recommended = new Set<number>();
  for (const rule of settings.weekly) {
    if (rule.weekday !== weekday) continue;
    const window = interval(request.day, rule.startMinutes, rule.endMinutes, zone);
    if (!window) continue;

    const candidates = new Set<number>();
    // "Match the service" tiles the stretch with whole visits, so its grid starts once the first prep is done.
    const origin = request.stepMinutes > 0 ? window.start : window.start + prep;
    for (let start = origin; start + duration <= window.end; start += step) candidates.add(start);
    candidates.add(roundUp(window.start + prep));
    candidates.add(roundDown(window.end - cleanup - duration));
    for (const segment of obstacles) {
      candidates.add(roundUp(segment.end + (segment.bufferedEnd ? buffer : 0) + prep));
      candidates.add(roundDown(segment.start - (segment.bufferedStart ? buffer : 0) - cleanup - duration));
    }

    const placements: Placement[] = [];
    for (const start of [...candidates].sort((a, b) => a - b)) {
      const outer: Segment = { start: start - prep, end: start + duration + cleanup, bufferedStart: true, bufferedEnd: true };
      if (start < earliest || outer.start < window.start || outer.end > window.end) continue;
      if (closed.some((segment) => conflicts(outer, segment, 0))) continue;
      const own = segmentsOf(start, start + duration, timing);
      if (own.some((mine) => visits.some((other) => conflicts(mine, other, buffer)))) continue;
      all.add(start);
      placements.push(placement(start, outer, window, obstacles, buffer, shortest));
    }
    for (const start of ranked ? compactStarts(placements) : placements.map((value) => value.start)) recommended.add(start);
  }
  return { all: [...all].sort((a, b) => a - b), recommended: [...recommended].sort((a, b) => a - b) };
}

/** The stretches a visit holds her: prep + visit + clean-up, split around its processing stretch when it has one. */
function segmentsOf(start: number, end: number, timing: VisitTiming): Segment[] {
  const outerStart = start - Math.max(timing.prepMinutes, 0) * MINUTE_MS;
  const outerEnd = end + Math.max(timing.cleanupMinutes, 0) * MINUTE_MS;
  const gapStart = start + timing.processingStartMinutes * MINUTE_MS;
  const gapEnd = gapStart + timing.processingMinutes * MINUTE_MS;
  const hasGap = timing.processingMinutes > 0 && timing.processingStartMinutes >= 0 && gapEnd <= end;
  const segments: Segment[] = hasGap
    ? [
        { start: outerStart, end: gapStart, bufferedStart: true, bufferedEnd: false },
        { start: gapEnd, end: outerEnd, bufferedStart: false, bufferedEnd: true }
      ]
    : [{ start: outerStart, end: outerEnd, bufferedStart: true, bufferedEnd: true }];
  return segments.filter((segment) => segment.end > segment.start);
}

/** The gap a free start sits in and the dead time it leaves on each side (D56). */
function placement(
  start: number,
  outer: Segment,
  window: Interval,
  obstacles: Segment[],
  buffer: number,
  shortest: number
): Placement {
  // The minimum notice is not an edge: time that has passed is lost whichever start she gets, so it hides nothing.
  let previous = window.start;
  let next = window.end;
  for (const segment of obstacles) {
    if (segment.end <= outer.start) previous = Math.max(previous, segment.end + (segment.bufferedEnd ? buffer : 0));
    if (segment.start >= outer.end) next = Math.min(next, segment.start - (segment.bufferedStart ? buffer : 0));
  }
  const needed = shortest + buffer;
  let deadMs = 0;
  let deadCount = 0;
  for (const slack of [outer.start - previous, next - outer.end]) {
    if (slack > 0 && slack < needed) {
      deadMs += slack;
      deadCount += 1;
    }
  }
  return { start, gap: `${previous}|${next}`, deadMs, deadCount };
}

/** Per gap: the starts that leave no dead time, or else the least dead time and then the fewest dead fragments. */
function compactStarts(placements: Placement[]): number[] {
  const best = new Map<string, Placement>();
  for (const item of placements) {
    const current = best.get(item.gap);
    if (!current || isBetter(item, current)) best.set(item.gap, item);
  }
  return placements
    .filter((item) => {
      const winner = best.get(item.gap);
      return item.deadMs === winner?.deadMs && item.deadCount === winner.deadCount;
    })
    .map((item) => item.start);
}

function isBetter(first: Placement, second: Placement): boolean {
  return first.deadMs < second.deadMs || (first.deadMs === second.deadMs && first.deadCount < second.deadCount);
}

const ROUNDING_MS = ANCHOR_ROUNDING_MINUTES * MINUTE_MS;

function roundUp(instant: number): number {
  return Math.ceil(instant / ROUNDING_MS) * ROUNDING_MS;
}

function roundDown(instant: number): number {
  return Math.floor(instant / ROUNDING_MS) * ROUNDING_MS;
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

/** Two stretches clash when the gap between them is smaller than the buffer owed at the edges that meet. */
function conflicts(first: Segment, second: Segment, buffer: number): boolean {
  const afterSecond = second.bufferedEnd && first.bufferedStart ? buffer : 0;
  const afterFirst = first.bufferedEnd && second.bufferedStart ? buffer : 0;
  return first.start < second.end + afterSecond && second.start < first.end + afterFirst;
}

/** Two stretches overlap if the gap between them is smaller than `margin`. */
export function overlaps(first: Interval, second: Interval, margin: number): boolean {
  return first.start < second.end + margin && first.end + margin > second.start;
}
