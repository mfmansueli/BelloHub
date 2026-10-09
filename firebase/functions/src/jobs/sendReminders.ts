import type { Deps } from '../app/Deps.js';
import { withNewTokenHash, tokenHash } from '../lib/bookingAccess.js';
import type { AvailabilityDoc, BookingDoc } from '../lib/docs.js';
import { dataOf, ms, refs, ts } from '../lib/store.js';
import { addDays, instantAtLocal, localDateOf } from '../lib/time.js';

const LOOKAHEAD_MS = 48 * 3_600_000;
const MAX_PER_RUN = 300;
const DEFAULT_REMINDER_HOUR = 18;

export interface ReminderReport {
  skipped: boolean;
  sent: number;
  failed: number;
}

/**
 * The instant a reminder is due: `hourLocal` o'clock the day before the visit, in the professional's time zone (D31,
 * docs/10 section 9: 18:00 the day before by default). Pure, so it is table-tested across daylight-saving days.
 */
export function reminderDueAt(startsAt: number, timeZoneID: string, hourLocal: number): number {
  const visitDay = localDateOf(startsAt, timeZoneID);
  return instantAtLocal(addDays(visitDay, -1), hourLocal * 60, timeZoneID);
}

function timeOfDay(instant: number, timeZone: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, { hour: 'numeric', minute: '2-digit', timeZone }).format(new Date(instant));
}

function dateTime(instant: number, timeZone: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    hour: 'numeric',
    minute: '2-digit',
    timeZone
  }).format(new Date(instant));
}

/**
 * Sends the client's reminder through WhatsApp, but ONLY when automation is on (D31): otherwise the app prepares the
 * reminders and the professional sends them. The personal link in the message needs a token, and the server stores only
 * hashes, so each reminder mints one more valid link for that booking (at most five stay valid).
 */
export async function runReminders(deps: Deps, now: number = deps.now()): Promise<ReminderReport> {
  if (!deps.settings.whatsAppAutomation || !deps.messenger.whatsAppAvailable) {
    return { skipped: true, sent: 0, failed: 0 };
  }
  const r = refs(deps.db);
  const upcoming = await r
    .bookings()
    .where('startsAt', '>', ts(now))
    .where('startsAt', '<=', ts(now + LOOKAHEAD_MS))
    .limit(MAX_PER_RUN)
    .get();

  const hourByOwner = new Map<string, number>();
  let sent = 0;
  let failed = 0;
  for (const snapshot of upcoming.docs) {
    const booking = snapshot.data() as BookingDoc;
    if (booking.status !== 'confirmed' || booking.reminderSentAt) continue;

    let hour = hourByOwner.get(booking.ownerUid);
    if (hour === undefined) {
      hour = dataOf<AvailabilityDoc>(await r.availability(booking.ownerUid).get())?.reminderHourLocal ?? DEFAULT_REMINDER_HOUR;
      hourByOwner.set(booking.ownerUid, hour);
    }
    const startsAt = ms(booking.startsAt);
    if (now < reminderDueAt(startsAt, booking.timeZoneID, hour)) continue;

    const token = deps.random.token();
    const profileName = dataOf<{ displayName: string }>(await r.profile(booking.slug).get())?.displayName ?? '';
    try {
      await deps.messenger.sendWhatsApp({
        template: 'reminder',
        to: booking.client.phone,
        locale: booking.client.locale,
        parameters: {
          name: booking.client.name,
          time: timeOfDay(startsAt, booking.timeZoneID, booking.client.locale),
          service: booking.serviceName,
          professional: profileName,
          deadline: dateTime(startsAt - booking.policy.freeWindowHours * 3_600_000, booking.timeZoneID, booking.client.locale),
          link: `${deps.settings.webBaseUrl}/m/${token}`
        }
      });
      await snapshot.ref.update({
        manageTokenHashes: withNewTokenHash(booking.manageTokenHashes, tokenHash(token)),
        reminderSentAt: ts(now),
        updatedAt: ts(now)
      });
      sent += 1;
    } catch {
      failed += 1;
    }
  }
  deps.log.info('reminders.done', { job: 'sendReminders', sent, failed });
  return { skipped: false, sent, failed };
}
