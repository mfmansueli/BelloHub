import type { Deps } from '../app/Deps.js';
import { RATE } from '../config/limits.js';
import { LocaleSchema } from '../contracts/common.js';
import type { LocaleId } from '../contracts/common.js';
import { findBookingByToken } from '../lib/bookingAccess.js';
import { ACTIVE_BOOKING_STATUSES } from '../lib/docs.js';
import type { PublicProfileDoc } from '../lib/docs.js';
import { isAppError } from '../lib/errors.js';
import { buildIcs } from '../lib/ics.js';
import { consumeRate } from '../lib/rateLimit.js';
import { dataOf, ms, plainReader, refs } from '../lib/store.js';

export interface IcsResponse {
  status: 200 | 404 | 410 | 429;
  body: string;
  headers: Record<string, string>;
}

const FAILURE_HEADERS = { 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' };

function failure(status: 404 | 410 | 429): IcsResponse {
  return { status, body: '', headers: FAILURE_HEADERS };
}

/** `GET getIcs?token=&locale=`: the .ics file of one booking, for whoever holds its manage link. */
export async function handleIcs(
  deps: Deps,
  query: { token?: unknown; locale?: unknown },
  ipHash: string
): Promise<IcsResponse> {
  try {
    await consumeRate(deps, 'ics', ipHash, RATE.icsIp);
  } catch {
    return failure(429);
  }
  const token = typeof query.token === 'string' && /^[A-Za-z0-9_-]{22}$/.test(query.token) ? query.token : undefined;
  if (!token) return failure(404);

  try {
    const now = deps.now();
    const booking = await findBookingByToken(plainReader, deps.db, token, now);
    if (!ACTIVE_BOOKING_STATUSES.includes(booking.data.status)) return failure(410);
    const profile = dataOf<PublicProfileDoc>(await refs(deps.db).profile(booking.data.slug).get());
    const parsed = LocaleSchema.safeParse(query.locale);
    const locale: LocaleId = parsed.success ? parsed.data : booking.data.client.locale;
    const body = buildIcs({
      bookingId: booking.id,
      serviceName: booking.data.serviceName,
      professionalName: profile?.displayName ?? '',
      city: profile?.city,
      startsAt: ms(booking.data.startsAt),
      endsAt: ms(booking.data.endsAt),
      tentative: booking.data.status === 'pendingApproval',
      link: `${deps.settings.webBaseUrl}/m/${token}`,
      now,
      locale
    });
    return {
      status: 200,
      body,
      headers: {
        'Content-Type': 'text/calendar; charset=utf-8',
        'Content-Disposition': 'attachment; filename="appointment.ics"',
        ...FAILURE_HEADERS
      }
    };
  } catch (error) {
    if (isAppError(error) && error.code === 'TOKEN_EXPIRED') return failure(410);
    if (isAppError(error) && error.code === 'NOT_FOUND') return failure(404);
    deps.log.error('ics.failed', { function: 'getIcs' });
    return failure(404);
  }
}
