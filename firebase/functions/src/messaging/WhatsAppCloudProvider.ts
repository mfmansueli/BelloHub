import { AppError } from '../lib/errors.js';
import type { WhatsAppProvider, WhatsAppTemplateMessage } from './WhatsAppProvider.js';

export interface WhatsAppCloudConfig {
  phoneNumberId: string;
  accessToken: string;
  graphVersion?: string;
}

type FetchLike = (url: string, init: { method: string; headers: Record<string, string>; body: string }) => Promise<{
  ok: boolean;
  status: number;
}>;

/**
 * Meta's WhatsApp Business Cloud API. The access token comes from Secret Manager (`WHATSAPP_ACCESS_TOKEN`, H13);
 * this class never logs the number or the parameters. Template messages only: free text is not allowed outside the
 * 24 hour window and nothing here would be clinical anyway.
 */
export class WhatsAppCloudProvider implements WhatsAppProvider {
  readonly enabled = true;
  private readonly endpoint: string;

  constructor(
    private readonly config: WhatsAppCloudConfig,
    private readonly fetchFn: FetchLike = fetch
  ) {
    this.endpoint = `https://graph.facebook.com/${config.graphVersion ?? 'v21.0'}/${config.phoneNumberId}/messages`;
  }

  async sendTemplate(message: WhatsAppTemplateMessage): Promise<void> {
    const body = {
      messaging_product: 'whatsapp',
      to: message.to.replace(/^\+/, ''),
      type: 'template',
      template: {
        name: message.templateName,
        language: { code: message.languageCode },
        components: [
          { type: 'body', parameters: message.parameters.map((text) => ({ type: 'text', text })) }
        ]
      }
    };
    const response = await this.fetchFn(this.endpoint, {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.config.accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    if (!response.ok) throw new AppError(response.status >= 500 ? 'TRY_AGAIN' : 'INTERNAL');
  }
}
