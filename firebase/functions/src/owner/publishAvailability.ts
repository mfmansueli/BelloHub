import { defineUseCase, ownerUid } from '../app/UseCase.js';
import { RATE } from '../config/limits.js';
import { instantMs, iso } from '../contracts/common.js';
import * as contract from '../contracts/owner.js';
import { ensureAccountExists } from '../lib/account.js';
import { timingFields, timingOf } from '../lib/calendar.js';
import type { AvailabilityDoc } from '../lib/docs.js';
import { AppError } from '../lib/errors.js';
import { consumeRate } from '../lib/rateLimit.js';
import { refs, ts } from '../lib/store.js';

const DEFAULT_REMINDER_HOUR = 18;
const DAY_MS = 86_400_000;

/**
 * Stores the scheduling rules the booking functions evaluate (docs/05 layer B: weekly hours, breaks, days off, buffer,
 * busy blocks without names or reasons, and the no-show policy). Function-only data: no client can read it.
 */
export const publishAvailability = defineUseCase({
  name: 'publishAvailability',
  access: 'owner',
  ...contract.publishAvailability,
  async handle(deps, input, ctx) {
    const uid = ownerUid(ctx);
    await consumeRate(deps, 'publish', uid, RATE.publishOwner);
    await ensureAccountExists(deps, uid, ctx);
    const now = deps.now();

    for (const rule of [...input.weekly, ...input.breaks]) {
      if (rule.endMinutes <= rule.startMinutes) throw new AppError('INVALID_ARGUMENT', { fields: ['weekly'] });
    }
    for (const off of input.daysOff) {
      if (off.endDate < off.startDate) throw new AppError('INVALID_ARGUMENT', { fields: ['daysOff'] });
    }

    // The past cannot block anything, so it is dropped to keep the document small.
    // An appointment keeps its extra and processing time (D56); a block is only closed time.
    const busy = input.busy
      .map((entry) => ({ start: instantMs(entry.startsAt), end: instantMs(entry.endsAt), kind: entry.kind, timing: timingOf(entry) }))
      .filter((entry) => entry.end > entry.start && entry.end > now - DAY_MS)
      .map((entry) => ({
        start: ts(entry.start),
        end: ts(entry.end),
        kind: entry.kind,
        ...(entry.kind === 'appointment' ? timingFields(entry.timing) : {})
      }));

    const doc: AvailabilityDoc = {
      ownerUid: uid,
      timeZoneID: input.timeZoneID,
      weekly: input.weekly,
      breaks: input.breaks.map((rule) => ({
        ...(rule.weekday !== undefined ? { weekday: rule.weekday } : {}),
        startMinutes: rule.startMinutes,
        endMinutes: rule.endMinutes
      })),
      daysOff: input.daysOff,
      bufferMinutes: input.bufferMinutes,
      minNoticeHours: input.minNoticeHours,
      maxDaysAhead: input.maxDaysAhead,
      ...(input.slotStepMinutes !== undefined ? { slotStepMinutes: input.slotStepMinutes } : {}),
      ...(input.compactDay !== undefined ? { compactDay: input.compactDay } : {}),
      busy,
      noShow: input.noShow,
      reminderHourLocal: input.reminderHourLocal ?? DEFAULT_REMINDER_HOUR,
      updatedAt: ts(now)
    };
    await refs(deps.db).availability(uid).set(doc);
    return { updatedAt: iso(now) };
  }
});
