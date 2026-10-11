import type { LocaleId } from '../contracts/common.js';
import type { PublicLocation } from '../lib/docs.js';
import type { EmailTemplateId } from './emailTemplates.js';
import type { TemplateVars } from './render.js';
import type { WhatsAppParameter, WhatsAppTemplateId } from './whatsAppTemplates.js';

export interface EmailRequest {
  template: EmailTemplateId;
  to: string;
  locale: LocaleId;
  vars: TemplateVars;
  /** Where she works, only when this client may see it (`lib/location.ts`). */
  place?: PublicLocation | undefined;
  /** The client's personal link to change or cancel, shown once more as a button in the HTML part. */
  manageLink?: string | undefined;
}

export interface WhatsAppRequest {
  template: WhatsAppTemplateId;
  to: string;
  locale: LocaleId;
  parameters: Partial<Record<WhatsAppParameter, string>>;
}

/**
 * Everything the server says to a client (D31). Use cases depend on this interface only, so providers can change
 * without touching a rule. Content is booking facts and a link; nothing clinical, ever (docs/06 section 8).
 */
export interface ClientMessenger {
  /** An email provider is configured, so `sendEmail` can succeed. */
  readonly emailAvailable: boolean;
  /** WhatsApp automation is on and configured (D31); when false reminders are prepared in the app. */
  readonly whatsAppAvailable: boolean;
  sendEmail(request: EmailRequest): Promise<void>;
  sendWhatsApp(request: WhatsAppRequest): Promise<void>;
}
