// The WhatsApp templates Meta must approve (H13), keyed by localization (docs/16-MARKETS.md section 3).
// Parameters use the same placeholders as docs/strings/message-templates.json, in the order the Meta template body
// declares them, and a test keeps the two files in step. Appointment confirmations and reminders are the "utility"
// category; the verification code is "authentication".

import type { LocaleId } from '../contracts/common.js';

export type WhatsAppTemplateId = 'confirmation' | 'reminder' | 'code';

export type WhatsAppParameter = 'name' | 'service' | 'professional' | 'date' | 'time' | 'deadline' | 'link' | 'code';

export interface WhatsAppTemplateDefinition {
  /** Parameters in body order. */
  parameters: readonly WhatsAppParameter[];
  category: 'utility' | 'authentication';
}

export const WHATSAPP_TEMPLATES: Record<WhatsAppTemplateId, WhatsAppTemplateDefinition> = {
  // message-templates.json "confirmation": {name} {service} {date} {time} {professional} {link}
  confirmation: { parameters: ['name', 'service', 'date', 'time', 'professional', 'link'], category: 'utility' },
  // "reminder": {name} {time} {service} {professional} {deadline} {link}
  reminder: { parameters: ['name', 'time', 'service', 'professional', 'deadline', 'link'], category: 'utility' },
  code: { parameters: ['code'], category: 'authentication' }
};

/** Meta's language codes for our localizations. */
export const WHATSAPP_LANGUAGE: Record<LocaleId, string> = {
  'pt-BR': 'pt_BR',
  'pt-PT': 'pt_PT',
  'es-MX': 'es_MX',
  'es-419': 'es_MX',
  es: 'es_ES',
  en: 'en_US',
  'en-GB': 'en_GB',
  it: 'it',
  fr: 'fr',
  de: 'de',
  tr: 'tr',
  id: 'id',
  hi: 'hi',
  ar: 'ar'
};

/** The template name registered with Meta: one set per language, e.g. `bellohub_reminder_pt_br`. */
export function whatsAppTemplateName(template: WhatsAppTemplateId, locale: LocaleId): string {
  return `bellohub_${template}_${WHATSAPP_LANGUAGE[locale].toLowerCase()}`;
}
