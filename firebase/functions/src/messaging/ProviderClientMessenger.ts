import { AppError } from '../lib/errors.js';
import type { ClientMessenger, EmailRequest, WhatsAppRequest } from './ClientMessenger.js';
import { DisabledEmailProvider } from './DisabledEmailProvider.js';
import { DisabledWhatsAppProvider } from './DisabledWhatsAppProvider.js';
import type { EmailProvider } from './EmailProvider.js';
import { emailTextsFor } from './emailTemplates.js';
import { fillTemplate } from './render.js';
import type { WhatsAppProvider } from './WhatsAppProvider.js';
import { WHATSAPP_LANGUAGE, WHATSAPP_TEMPLATES, whatsAppTemplateName } from './whatsAppTemplates.js';

/** Renders the templates and hands the result to whichever providers are configured. */
export class ProviderClientMessenger implements ClientMessenger {
  constructor(
    private readonly email: EmailProvider = new DisabledEmailProvider(),
    private readonly whatsApp: WhatsAppProvider = new DisabledWhatsAppProvider(),
    private readonly emailConfigured = false
  ) {}

  get emailAvailable(): boolean {
    return this.emailConfigured;
  }

  get whatsAppAvailable(): boolean {
    return this.whatsApp.enabled;
  }

  async sendEmail(request: EmailRequest): Promise<void> {
    const text = emailTextsFor(request.locale)[request.template];
    await this.email.send({
      to: request.to,
      subject: fillTemplate(text.subject, request.vars, request.locale),
      text: fillTemplate(text.body, request.vars, request.locale)
    });
  }

  async sendWhatsApp(request: WhatsAppRequest): Promise<void> {
    if (!this.whatsApp.enabled) throw new AppError('NOT_CONFIGURED');
    const definition = WHATSAPP_TEMPLATES[request.template];
    await this.whatsApp.sendTemplate({
      to: request.to,
      templateName: whatsAppTemplateName(request.template, request.locale),
      languageCode: WHATSAPP_LANGUAGE[request.locale],
      parameters: definition.parameters.map((name) => request.parameters[name] ?? '')
    });
  }
}
