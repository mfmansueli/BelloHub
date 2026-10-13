// A professional's calendar as the server sees it: what she published, what is booked, what is on hold. Used by
// getSlots, holdSlot, createBooking, rescheduling and every other use case that needs "is this time free".
//
// Double booking (D32) is prevented by serialization: everything that OCCUPIES time reads and then bumps one
// `calendarLocks/{ownerUid}` document inside its transaction. Two such transactions for one professional therefore
// conflict, and the one that retries sees the other's booking. This does not depend on how a database treats a
// concurrent insert into a queried range.

import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { FieldValue } from 'firebase-admin/firestore';

import type { Reader } from './store.js';
import { dataOf, ms, refs, ts, txReader } from './store.js';
import { ALTERNATIVES_SEARCH_DAYS, MAX_ALTERNATIVES } from '../config/limits.js';
import { AppError } from './errors.js';
import type { AccountDoc, AvailabilityDoc, BookingDoc, HoldDoc, PublicProfileDoc, SlugDoc, TimingFields } from './docs.js';
import { ACTIVE_BOOKING_STATUSES } from './docs.js';
import type { AvailabilitySettings, Interval, SlotPlan, TimedInterval, VisitTiming } from './freeSlots.js';
import { SLOT_STEP_MINUTES, hasOccupiedConflict, planSlots } from './freeSlots.js';
import { MAX_TOTAL_MINUTES, totalMinutes } from './rules.js';
import { addDays, localDateOf } from './time.js';

const MINUTE_MS = 60_000;
const DAY_MS = 86_400_000;
export const MAX_TOTAL_MS = MAX_TOTAL_MINUTES * MINUTE_MS;

export interface Calendar {
  ownerUid: string;
  slug: string;
  profile: PublicProfileDoc;
  /** Undefined until the professional publishes her availability: then nothing is bookable. */
  availability: AvailabilityDoc | undefined;
  account: AccountDoc;
}

/** Reads the three documents that describe a bookable professional. Null when the slug is unknown or incomplete. */
export async function loadCalendar(reader: Reader, db: Firestore, slug: string): Promise<Calendar | null> {
  const r = refs(db);
  const claim = dataOf<SlugDoc>(await reader.doc(r.slug(slug)));
  if (!claim) return null;
  const [profileSnap, availabilitySnap, accountSnap] = await Promise.all([
    reader.doc(r.profile(slug)),
    reader.doc(r.availability(claim.ownerUid)),
    reader.doc(r.account(claim.ownerUid))
  ]);
  const profile = dataOf<PublicProfileDoc>(profileSnap);
  const account = dataOf<AccountDoc>(accountSnap);
  if (!profile || !account) return null;
  return { ownerUid: claim.ownerUid, slug, profile, availability: dataOf<AvailabilityDoc>(availabilitySnap), account };
}

export function slotSettings(calendar: Calendar): AvailabilitySettings | undefined {
  const a = calendar.availability;
  if (!a) return undefined;
  return {
    weekly: a.weekly,
    breaks: a.breaks,
    daysOff: a.daysOff,
    bufferMinutes: a.bufferMinutes,
    minNoticeHours: a.minNoticeHours,
    maxDaysAhead: a.maxDaysAhead,
    timeZoneID: a.timeZoneID
  };
}

/** D56: how her day is offered: the grid, the compact-day ranking and the shortest offer it measures gaps with. */
export interface SlotPolicy {
  stepMinutes: number;
  compact: boolean;
  shortestOfferMinutes: number;
}

export function slotPolicy(calendar: Calendar): SlotPolicy {
  return {
    stepMinutes: calendar.availability?.slotStepMinutes ?? SLOT_STEP_MINUTES,
    compact: calendar.availability?.compactDay ?? true,
    shortestOfferMinutes: shortestOfferMinutes(calendar.profile)
  };
}

/** Her shortest published service with its extra time (D56); 0 when she publishes none. */
export function shortestOfferMinutes(profile: PublicProfileDoc): number {
  const lengths = profile.services.map((service) => {
    const timing = timingOf(service);
    return timing.prepMinutes + service.durationMinutes + timing.cleanupMinutes;
  });
  return lengths.length === 0 ? 0 : Math.min(...lengths);
}

/** The shape of a visit from its stored fields (absent is 0). */
export function timingOf(fields: TimingFields): VisitTiming {
  return {
    prepMinutes: fields.prepMinutes ?? 0,
    cleanupMinutes: fields.cleanupMinutes ?? 0,
    processingStartMinutes: fields.processingStartMinutes ?? 0,
    processingMinutes: fields.processingMinutes ?? 0
  };
}

/** The fields to snapshot on a booking or a hold: only the ones that are not 0, so plain visits stay as before. */
export function timingFields(timing: VisitTiming): TimingFields {
  const fields: TimingFields = {};
  if (timing.prepMinutes > 0) fields.prepMinutes = timing.prepMinutes;
  if (timing.cleanupMinutes > 0) fields.cleanupMinutes = timing.cleanupMinutes;
  if (timing.processingMinutes > 0) {
    fields.processingStartMinutes = timing.processingStartMinutes;
    fields.processingMinutes = timing.processingMinutes;
  }
  return fields;
}

/** What a time is checked for: the visible length and the shape of the visit. */
export interface SlotOffer {
  durationMinutes: number;
  timing: VisitTiming;
}

/** A booked visit as an offer: its own length and its snapshot of extra and processing time (moving keeps its shape). */
export function bookingOffer(booking: BookingDoc): SlotOffer {
  return { durationMinutes: booking.durationMinutes, timing: timingOf(booking) };
}

// MARK: - What is offered

export interface OfferInput {
  serviceId: string;
  addOnIds?: readonly string[] | undefined;
  guests?: number | undefined;
}

export interface ResolvedOffer {
  serviceId: string;
  serviceName: string;
  addOns: { id: string; name: string; minutes: number }[];
  guests: number;
  /** Service + add-ons + guests back to back (D19). */
  durationMinutes: number;
  /** The service's extra and processing time (D56); it wraps the whole visit. */
  timing: VisitTiming;
}

/** The service and add-ons the professional published, and the total time they take. Never trusts a client duration. */
export function resolveOffer(profile: PublicProfileDoc, input: OfferInput): ResolvedOffer {
  const service = profile.services.find((candidate) => candidate.id === input.serviceId);
  if (!service) throw new AppError('NOT_FOUND');
  const ids = input.addOnIds ?? [];
  if (new Set(ids).size !== ids.length) throw new AppError('INVALID_ARGUMENT', { fields: ['addOnIds'] });
  const addOns = ids.map((id) => {
    const found = profile.addOns.find((candidate) => candidate.id === id);
    if (!found) throw new AppError('NOT_FOUND');
    return { id: found.id, name: found.name, minutes: found.minutes };
  });
  const guests = input.guests ?? 0;
  if (guests > profile.booking.maxGuests) throw new AppError('INVALID_ARGUMENT', { fields: ['guests'] });
  const durationMinutes = totalMinutes(service.durationMinutes, addOns.map((addOn) => addOn.minutes), guests);
  if (durationMinutes > MAX_TOTAL_MINUTES) throw new AppError('INVALID_ARGUMENT', { fields: ['addOnIds'] });
  return { serviceId: service.id, serviceName: service.name, addOns, guests, durationMinutes, timing: timingOf(service) };
}

// MARK: - What occupies time

export interface Occupied {
  /** Bookings and holds, with their shape: a buffer is kept around them. */
  appointments: TimedInterval[];
  /** Blocks she closed in her own agenda: no buffer. */
  blocks: Interval[];
}

export interface OccupiedOptions {
  /** A booking being moved: its own time does not block it. */
  excludeBookingId?: string | undefined;
  /** Keyed hash of the caller's hold key: her own hold does not block her. */
  ownHoldKeyHash?: string | undefined;
}

/** Everything that occupies time in `range`, read through `reader` (so inside a transaction the reads are locked in). */
export async function loadOccupied(
  reader: Reader,
  db: Firestore,
  calendar: Calendar,
  range: Interval,
  now: number,
  options: OccupiedOptions = {}
): Promise<Occupied> {
  const r = refs(db);
  const [bookingSnaps, holdSnaps] = await Promise.all([
    reader.query(
      r
        .bookings()
        .where('ownerUid', '==', calendar.ownerUid)
        .where('startsAt', '>=', ts(range.start - MAX_TOTAL_MS))
        .where('startsAt', '<', ts(range.end))
    ),
    reader.query(r.holds().where('ownerUid', '==', calendar.ownerUid))
  ]);

  const appointments: TimedInterval[] = [];
  const blocks: Interval[] = [];
  const registeredIds = new Set(bookingSnaps.docs.map((snap) => snap.id));
  for (const snap of bookingSnaps.docs) {
    const booking = snap.data() as BookingDoc;
    if (snap.id === options.excludeBookingId || !ACTIVE_BOOKING_STATUSES.includes(booking.status)) continue;
    appointments.push({ start: ms(booking.startsAt), end: ms(booking.endsAt), timing: timingOf(booking) });
  }
  for (const snap of holdSnaps.docs) {
    const hold = snap.data() as HoldDoc;
    if (ms(hold.expiresAt) <= now || hold.holdKeyHash === options.ownHoldKeyHash) continue;
    appointments.push({ start: ms(hold.startsAt), end: ms(hold.endsAt), timing: timingOf(hold) });
  }
  for (const entry of calendar.availability?.busy ?? []) {
    // The BookingDoc is authoritative once registered, even if a publish from an older phone still lists this visit.
    if (entry.kind === 'appointment' && entry.appointmentId &&
      (entry.appointmentId === options.excludeBookingId || registeredIds.has(entry.appointmentId))) continue;
    const interval = { start: ms(entry.start), end: ms(entry.end) };
    if (entry.kind === 'appointment') appointments.push({ ...interval, timing: timingOf(entry) });
    else blocks.push(interval);
  }
  return { appointments, blocks };
}

/** Owner-chosen times may be outside published hours, but must not overlap another occupied time. */
export function isOccupied(occupied: Occupied, start: number, end: number, offer: SlotOffer, bufferMinutes: number): boolean {
  return hasOccupiedConflict(
    { start, end, timing: offer.timing }, occupied.appointments, occupied.blocks, bufferMinutes
  );
}

// MARK: - Free starts

/** Every free start of a local day and the ones to show first (D56). */
export function planOn(calendar: Calendar, day: string, offer: SlotOffer, now: number, occupied: Occupied): SlotPlan {
  const settings = slotSettings(calendar);
  if (!settings) return { all: [], recommended: [] };
  const policy = slotPolicy(calendar);
  return planSlots({
    day,
    durationMinutes: offer.durationMinutes,
    now,
    settings,
    appointments: occupied.appointments,
    blocks: occupied.blocks,
    stepMinutes: policy.stepMinutes,
    timing: offer.timing,
    compact: policy.compact,
    shortestOfferMinutes: policy.shortestOfferMinutes
  });
}

/** Every free start of a local day: any of them can be held and booked, recommended or not. */
export function freeStartsOn(calendar: Calendar, day: string, offer: SlotOffer, now: number, occupied: Occupied): number[] {
  return planOn(calendar, day, offer, now, occupied).all;
}

/** Is `startsAt` one of the offered starts of its local day? */
export function isStartFree(calendar: Calendar, startsAt: number, offer: SlotOffer, now: number, occupied: Occupied): boolean {
  const settings = slotSettings(calendar);
  if (!settings) return false;
  const day = localDateOf(startsAt, settings.timeZoneID);
  return freeStartsOn(calendar, day, offer, now, occupied).includes(startsAt);
}

/** The next recommended starts at or after `from`, for "That time was just taken. Here are the next ones". */
export function nextFreeStarts(
  calendar: Calendar,
  from: number,
  offer: SlotOffer,
  now: number,
  occupied: Occupied,
  limit = MAX_ALTERNATIVES
): number[] {
  const settings = slotSettings(calendar);
  if (!settings) return [];
  const found: number[] = [];
  let day = localDateOf(from, settings.timeZoneID);
  for (let offset = 0; offset <= ALTERNATIVES_SEARCH_DAYS && found.length < limit; offset += 1) {
    for (const start of planOn(calendar, day, offer, now, occupied).recommended) {
      if (start >= from && found.length < limit) found.push(start);
    }
    day = addDays(day, 1);
  }
  return found;
}

/** The range to load so `nextFreeStarts` can look ALTERNATIVES_SEARCH_DAYS ahead of `from`. */
export function alternativesRange(from: number): Interval {
  return { start: from, end: from + (ALTERNATIVES_SEARCH_DAYS + 2) * DAY_MS };
}

/** Is the time free for this offer, and if not, which starts are? Reads only; call it before any write. */
export async function checkSlot(
  reader: Reader,
  db: Firestore,
  calendar: Calendar,
  startsAt: number,
  offer: SlotOffer,
  now: number,
  options: OccupiedOptions = {}
): Promise<{ free: true } | { free: false; alternatives: number[] }> {
  const end = startsAt + offer.durationMinutes * MINUTE_MS;
  const near = await loadOccupied(reader, db, calendar, { start: startsAt - DAY_MS, end: end + DAY_MS }, now, options);
  if (isStartFree(calendar, startsAt, offer, now, near)) return { free: true };
  const wide = await loadOccupied(reader, db, calendar, alternativesRange(startsAt), now, options);
  return { free: false, alternatives: nextFreeStarts(calendar, startsAt, offer, now, wide) };
}

// MARK: - The serialization point

/** Read the lock inside the transaction BEFORE any write. */
export async function readCalendarLock(tx: Transaction, db: Firestore, ownerUid: string): Promise<void> {
  await txReader(tx).doc(refs(db).calendarLock(ownerUid));
}

/** Write the lock: any other transaction that read it now conflicts and retries against the new state. */
export function bumpCalendarLock(tx: Transaction, db: Firestore, ownerUid: string): void {
  tx.set(refs(db).calendarLock(ownerUid), { version: FieldValue.increment(1) }, { merge: true });
}
