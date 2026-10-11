import { AppError } from '../lib/errors.js';
import type { WhatsAppProvider, WhatsAppTemplateMessage } from './WhatsAppProvider.js';

/** The default (D31): nothing is sent by WhatsApp. The professional sends reminders herself with one tap. */
export class DisabledWhatsAppProvider implements WhatsAppProvider {
  readonly enabled = false;

  sendTemplate(_message: WhatsAppTemplateMessage): Promise<void> {
    return Promise.reject(new AppError('NOT_CONFIGURED'));
  }
}
