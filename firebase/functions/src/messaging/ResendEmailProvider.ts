import { AppError } from '../lib/errors.js';
import type { EmailMessage, EmailProvider } from './EmailProvider.js';
import { emailHtml } from './emailHtml.js';

export interface ResendConfig {
  /** The API key from Secret Manager (`EMAIL_API_KEY`, H7). */
  apiKey: string;
  /** The verified sender, `Bello Hub <no-reply@bellohub.app>` (`EMAIL_FROM`). */
  from: string;
  endpoint?: string | undefined;
}

type FetchLike = (url: string, init: { method: string; headers: Record<string, string>; body: string }) => Promise<{
  ok: boolean;
  status: number;
}>;

const DEFAULT_ENDPOINT = 'https://api.resend.com/emails';

/**
 * Transactional email over Resend's HTTPS API (H7): one JSON POST per message, a text part and a plain HTML part built from it (no images, no tracking). The class never logs
 * the address, the subject or the text, and a provider failure is a generic error (the booking carries on without its
 * email, D31). Changing vendor means replacing this one file: the request body is the only vendor-specific part.
 */
export class ResendEmailProvider implements EmailProvider {
  private readonly endpoint: string;

  constructor(
    private readonly config: ResendConfig,
    private readonly fetchFn: FetchLike = fetch
  ) {
    this.endpoint = config.endpoint ?? DEFAULT_ENDPOINT;
  }

  /** The provider when both the key and the sender are set; otherwise nothing, and the caller keeps `DisabledEmailProvider`. */
  static ifConfigured(config: { apiKey: string; from: string }, fetchFn?: FetchLike): ResendEmailProvider | undefined {
    const apiKey = config.apiKey.trim();
    const from = config.from.trim();
    if (!apiKey || !from) return undefined;
    return new ResendEmailProvider({ apiKey, from }, fetchFn);
  }

  async send(message: EmailMessage): Promise<void> {
    const response = await this.fetchFn(this.endpoint, {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.config.apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: this.config.from,
        to: [message.to],
        subject: message.subject,
        text: message.text,
        html: emailHtml(message.subject, message.text, message.lang)
      })
    });
    if (!response.ok) throw new AppError(response.status === 429 || response.status >= 500 ? 'TRY_AGAIN' : 'INTERNAL');
  }
}
