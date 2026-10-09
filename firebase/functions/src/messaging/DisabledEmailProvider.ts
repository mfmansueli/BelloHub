import { AppError } from '../lib/errors.js';
import type { EmailMessage, EmailProvider } from './EmailProvider.js';

/**
 * The provider while `EMAIL_FROM` and the `EMAIL_API_KEY` secret are not set (H7): every send fails with NOT_CONFIGURED,
 * so the web app offers SMS only and a booking simply carries on without its confirmation email.
 */
export class DisabledEmailProvider implements EmailProvider {
  send(_message: EmailMessage): Promise<void> {
    return Promise.reject(new AppError('NOT_CONFIGURED'));
  }
}
