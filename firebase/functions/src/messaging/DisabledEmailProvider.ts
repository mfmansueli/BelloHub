import { AppError } from '../lib/errors.js';
import type { EmailMessage, EmailProvider } from './EmailProvider.js';

/**
 * The provider until a human picks a vendor and stores its key (H7): every send fails with NOT_CONFIGURED, so the web
 * app offers SMS only and a booking simply carries on without its confirmation email.
 * TODO(HUMAN-H7): replace with the adapter of the chosen vendor in createDeps().
 */
export class DisabledEmailProvider implements EmailProvider {
  send(_message: EmailMessage): Promise<void> {
    return Promise.reject(new AppError('NOT_CONFIGURED'));
  }
}
