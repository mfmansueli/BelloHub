import type { Deps } from '../app/Deps.js';
import { RATE } from '../config/limits.js';
import type { BookingDoc } from './docs.js';
import type { EmailTemplateId } from '../messaging/emailTemplates.js';
import { formatWhen } from '../messaging/render.js';
import { loadLocation, shownLocation } from './location.js';
import { consumeRate } from './rateLimit.js';
import { ms } from './store.js';

/** The e-mails about a visit that is (or may become) hers, which say where she works when the client may see it. */
const PLACE_TEMPLATES: ReadonlySet<EmailTemplateId> = new Set(['bookingConfirmed', 'bookingPending', 'bookingApproved', 'bookingMoved']);

export interface BookingEmailInput {
  template: EmailTemplateId;
  booking: BookingDoc;
  professionalName: string;
  /** The raw manage token, when this call just made it. The server cannot recover it later. */
  manageToken?: string | undefined;
  /** Use the professional's page instead of the manage link (declined, cancelled by her). Ignored without a token. */
  linkToPage?: boolean;
}

/**
 * The booking email, best effort: a booking never fails because an email could not be sent (D31). It carries booking
 * facts and a link only. Returns whether an email went out.
 */
export async function sendBookingEmail(deps: Deps, input: BookingEmailInput): Promise<boolean> {
  const { booking } = input;
  const to = booking.client.email;
  if (!to || !deps.messenger.emailAvailable) return false;
  try {
    await consumeRate(deps, 'bookingEmailOwner', booking.ownerUid, RATE.bookingEmailOwnerDay);
  } catch {
    deps.log.warn('email.capped', { ownerUid: booking.ownerUid });
    return false;
  }
  const base = deps.settings.webBaseUrl;
  const toManage = !input.linkToPage && input.manageToken !== undefined;
  const link = toManage ? `${base}/m/${input.manageToken}` : `${base}/${booking.slug}`;
  try {
    // Where she works, by the one visibility rule (lib/location.ts): a request still waiting for her shows it only
    // when she put it on her page.
    const place = PLACE_TEMPLATES.has(input.template)
      ? shownLocation(await loadLocation(deps.db, booking.ownerUid).catch(() => undefined), booking.status)
      : undefined;
    await deps.messenger.sendEmail({
      template: input.template,
      to,
      locale: booking.client.locale,
      vars: {
        professional: input.professionalName,
        service: booking.serviceName,
        when: formatWhen(ms(booking.startsAt), booking.timeZoneID, booking.client.locale),
        link
      },
      place,
      manageLink: toManage ? link : undefined
    });
    return true;
  } catch {
    deps.log.warn('email.failed', { template: input.template });
    return false;
  }
}
