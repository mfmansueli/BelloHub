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
import type { AccountDoc, AvailabilityDoc, BookingDoc, HoldDoc, PublicProfileDoc, SlugDoc } from './docs.js';
import { ACTIVE_BOOKING_STATUSES } from './docs.js';
import type { AvailabilitySettings, Interval } from './freeSlots.js';
import { SLOT_STEP_MINUTES, freeSlots } from './freeSlots.js';
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
  return { serviceId: service.id, serviceName: service.name, addOns, guests, durationMinutes };
}

// MARK: - What occupies time

export interface Occupied {
  /** Bookings and holds: a buffer is kept around them. */
  appointments: Interval[];
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

  const appointments: Interval[] = [];
  const blocks: Interval[] = [];
  for (const snap of bookingSnaps.docs) {
    const booking = snap.data() as BookingDoc;
    if (snap.id === options.excludeBookingId || !ACTIVE_BOOKING_STATUSES.includes(booking.status)) continue;
    appointments.push({ start: ms(booking.startsAt), end: ms(booking.endsAt) });
  }
  for (const snap of holdSnaps.docs) {
    const hold = snap.data() as HoldDoc;
    if (ms(hold.expiresAt) <= now || hold.holdKeyHash === options.ownHoldKeyHash) continue;
    appointments.push({ start: ms(hold.startsAt), end: ms(hold.endsAt) });
  }
  for (const entry of calendar.availability?.busy ?? []) {
    const interval = { start: ms(entry.start), end: ms(entry.end) };
    (entry.kind === 'appointment' ? appointments : blocks).push(interval);
  }
  return { appointments, blocks };
}

// MARK: - Free starts

export function freeStartsOn(
  calendar: Calendar,
  day: string,
  durationMinutes: number,
  now: number,
  occupied: Occupied
): number[] {
  const settings = slotSettings(calendar);
  if (!settings) return [];
  return freeSlots({
    day,
    durationMinutes,
    now,
    settings,
    appointments: occupied.appointments,
    blocks: occupied.blocks,
    stepMinutes: SLOT_STEP_MINUTES
  });
}

/** Is `startsAt` one of the offered starts of its local day? */
export function isStartFree(
  calendar: Calendar,
  startsAt: number,
  durationMinutes: number,
  now: number,
  occupied: Occupied
): boolean {
  const settings = slotSettings(calendar);
  if (!settings) return false;
  const day = localDateOf(startsAt, settings.timeZoneID);
  return freeStartsOn(calendar, day, durationMinutes, now, occupied).includes(startsAt);
}

/** The next free starts at or after `from`, for "That time was just taken. Here are the next ones". */
export function nextFreeStarts(
  calendar: Calendar,
  from: number,
  durationMinutes: number,
  now: number,
  occupied: Occupied,
  limit = MAX_ALTERNATIVES
): number[] {
  const settings = slotSettings(calendar);
  if (!settings) return [];
  const found: number[] = [];
  let day = localDateOf(from, settings.timeZoneID);
  for (let offset = 0; offset <= ALTERNATIVES_SEARCH_DAYS && found.length < limit; offset += 1) {
    for (const start of freeStartsOn(calendar, day, durationMinutes, now, occupied)) {
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
  durationMinutes: number,
  now: number,
  options: OccupiedOptions = {}
): Promise<{ free: true } | { free: false; alternatives: number[] }> {
  const end = startsAt + durationMinutes * MINUTE_MS;
  const near = await loadOccupied(reader, db, calendar, { start: startsAt - DAY_MS, end: end + DAY_MS }, now, options);
  if (isStartFree(calendar, startsAt, durationMinutes, now, near)) return { free: true };
  const wide = await loadOccupied(reader, db, calendar, alternativesRange(startsAt), now, options);
  return { free: false, alternatives: nextFreeStarts(calendar, startsAt, durationMinutes, now, wide) };
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
