export interface WhatsAppTemplateMessage {
  /** E.164 number of the client. */
  to: string;
  /** The template name approved by Meta (H13), from whatsAppTemplates.ts. */
  templateName: string;
  /** Meta's language code, for example `pt_BR`. */
  languageCode: string;
  /** Body parameters in order, as the template defines them. */
  parameters: string[];
}

/** WhatsApp Business Cloud API (D31). Implemented and tested against a mock; disabled until a human completes Meta onboarding. */
export interface WhatsAppProvider {
  readonly enabled: boolean;
  sendTemplate(message: WhatsAppTemplateMessage): Promise<void>;
}
