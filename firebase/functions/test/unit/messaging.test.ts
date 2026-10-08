import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { LOCALES } from '../../src/contracts/common.js';
import { DisabledEmailProvider } from '../../src/messaging/DisabledEmailProvider.js';
import { DisabledWhatsAppProvider } from '../../src/messaging/DisabledWhatsAppProvider.js';
import { EMAIL_TEMPLATE_IDS, emailTextsFor } from '../../src/messaging/emailTemplates.js';
import { ProviderClientMessenger } from '../../src/messaging/ProviderClientMessenger.js';
import { fillTemplate, formatWhen, isolate } from '../../src/messaging/render.js';
import { WhatsAppCloudProvider } from '../../src/messaging/WhatsAppCloudProvider.js';
import { WHATSAPP_LANGUAGE, WHATSAPP_TEMPLATES, whatsAppTemplateName } from '../../src/messaging/whatsAppTemplates.js';
import { buildFcmMessage } from '../../src/push/fcmMessage.js';
import { PUSH_ALERT_KEYS } from '../../src/push/PushSender.js';
import { FakeEmailProvider } from '../support/fakes.js';

const placeholders = (text: string): string[] => [...new Set([...text.matchAll(/\{(\w+)\}/g)].map((match) => match[1] ?? ''))].sort();

describe('email templates (D24: fourteen localizations)', () => {
  it.each(LOCALES)('%s has every template, with a subject and a body', (locale) => {
    const texts = emailTextsFor(locale);

    for (const id of EMAIL_TEMPLATE_IDS) {
      expect(texts[id].subject.trim().length, `${locale}.${id}.subject`).toBeGreaterThan(5);
      expect(texts[id].body.trim().length, `${locale}.${id}.body`).toBeGreaterThan(20);
    }
  });

  it.each(EMAIL_TEMPLATE_IDS)('%s uses the same placeholders in every localization', (id) => {
    const reference = placeholders(`${emailTextsFor('en')[id].subject} ${emailTextsFor('en')[id].body}`);

    for (const locale of LOCALES) {
      const texts = emailTextsFor(locale)[id];
      expect(placeholders(`${texts.subject} ${texts.body}`), `${locale}.${id}`).toEqual(reference);
    }
  });

  it('knows only the five placeholders it can fill', () => {
    for (const locale of LOCALES) {
      for (const id of EMAIL_TEMPLATE_IDS) {
        const texts = emailTextsFor(locale)[id];
        for (const name of placeholders(`${texts.subject} ${texts.body}`)) {
          expect(['code', 'professional', 'service', 'when', 'link']).toContain(name);
        }
      }
    }
  });

  it('says nothing about health, treatment results or payment', () => {
    const forbidden = /alerg|allerg|saúde|health|santé|gesundheit|diagnos|payment|pagamento|pago|paiement|zahlung|invoice|fatura|\$|€|R\$/i;
    for (const locale of LOCALES) {
      for (const id of EMAIL_TEMPLATE_IDS) {
        const texts = emailTextsFor(locale)[id];
        expect(`${texts.subject} ${texts.body}`, `${locale}.${id}`).not.toMatch(forbidden);
      }
    }
  });

  it('reads es-419 as es-MX and en-GB as en', () => {
    expect(emailTextsFor('es-419')).toBe(emailTextsFor('es-MX'));
    expect(emailTextsFor('en-GB')).toBe(emailTextsFor('en'));
  });
});

describe('rendering', () => {
  it('fills placeholders and leaves nothing like "undefined"', () => {
    const text = fillTemplate('{service} with {professional}: {when} {link}{code}', { service: 'Facial', professional: 'Maria' }, 'en');

    expect(text).toBe('Facial with Maria:  ');
    expect(text).not.toContain('undefined');
  });

  it('isolates each value in Arabic and only in Arabic', () => {
    expect(fillTemplate('{professional}', { professional: 'Maria' }, 'ar')).toBe(isolate('Maria'));
    expect(fillTemplate('{professional}', { professional: 'Maria' }, 'pt-BR')).toBe('Maria');
  });

  it('formats the date in the reader\'s language and the professional\'s time zone', () => {
    const at = Date.parse('2026-10-03T13:00:00.000Z');

    expect(formatWhen(at, 'America/Sao_Paulo', 'en')).toMatch(/Saturday, October 3.*10:00/);
    expect(formatWhen(at, 'America/Sao_Paulo', 'pt-BR')).toMatch(/sábado.*3 de outubro.*10:00/);
    expect(formatWhen(at, 'Europe/Lisbon', 'pt-PT')).toMatch(/14:00/);
    expect(formatWhen(at, 'America/Sao_Paulo', 'de')).toMatch(/Samstag.*3\. Oktober.*10:00/);
    expect(formatWhen(at, 'America/Sao_Paulo', 'ar')).toMatch(/10:00/);
  });
});

describe('ClientMessenger', () => {
  it('renders the template for the locale and hands the result to the email provider', async () => {
    const provider = new FakeEmailProvider();
    const messenger = new ProviderClientMessenger(provider, new DisabledWhatsAppProvider(), true);

    await messenger.sendEmail({ template: 'bookingConfirmed', to: 'ana@example.com', locale: 'de', vars: { professional: 'Maria', service: 'Facial', when: 'Samstag', link: 'https://x/m/t' } });

    expect(provider.sent).toHaveLength(1);
    expect(provider.sent[0]).toMatchObject({ to: 'ana@example.com', subject: 'Ihr Termin bei Maria ist bestätigt' });
    expect(provider.sent[0]?.text).toContain('https://x/m/t');
  });

  it('is unavailable by default: no email provider and no WhatsApp until a human sets them up', async () => {
    const messenger = new ProviderClientMessenger();

    expect(messenger.emailAvailable).toBe(false);
    expect(messenger.whatsAppAvailable).toBe(false);
    await expect(messenger.sendEmail({ template: 'verificationCode', to: 'a@b.co', locale: 'en', vars: { code: '123456' } })).rejects.toMatchObject({ code: 'NOT_CONFIGURED' });
    await expect(messenger.sendWhatsApp({ template: 'reminder', to: '+5511900000000', locale: 'pt-BR', parameters: {} })).rejects.toMatchObject({ code: 'NOT_CONFIGURED' });
    await expect(new DisabledEmailProvider().send({ to: 'a@b.co', subject: 's', text: 't' })).rejects.toMatchObject({ code: 'NOT_CONFIGURED' });
    await expect(new DisabledWhatsAppProvider().sendTemplate({ to: '+1', templateName: 't', languageCode: 'en_US', parameters: [] })).rejects.toMatchObject({ code: 'NOT_CONFIGURED' });
  });
});

describe('WhatsApp templates (D31, kept in step with docs/strings/message-templates.json)', () => {
  const file = fileURLToPath(new URL('../../../../docs/strings/message-templates.json', import.meta.url));
  const catalog = JSON.parse(readFileSync(file, 'utf8')) as { locales: Record<string, { messages: Record<string, string> }> };

  it.each(Object.entries(catalog.locales))('the %s texts use exactly the parameters the server fills', (_locale, entry) => {
    const messages = entry.messages;
    const confirmation = messages.confirmation ?? '';
    const reminder = messages.reminder ?? '';

    expect(placeholders(confirmation)).toEqual([...WHATSAPP_TEMPLATES.confirmation.parameters].sort());
    expect(placeholders(reminder)).toEqual([...WHATSAPP_TEMPLATES.reminder.parameters].sort());
  });

  it('keeps the order of the parameters as the iOS text mentions them', () => {
    const english = catalog.locales.en?.messages.reminder ?? '';
    const order = [...english.matchAll(/\{(\w+)\}/g)].map((match) => match[1]);

    expect(order[0]).toBe(WHATSAPP_TEMPLATES.reminder.parameters[0]);
  });

  it('has a Meta language and a template name for every localization', () => {
    for (const locale of LOCALES) {
      expect(WHATSAPP_LANGUAGE[locale]).toMatch(/^[a-z]{2}(_[A-Z]{2})?$/);
      expect(whatsAppTemplateName('reminder', locale)).toMatch(/^bellohub_reminder_[a-z]{2}(_[a-z]{2})?$/);
    }
    expect(whatsAppTemplateName('reminder', 'pt-BR')).toBe('bellohub_reminder_pt_br');
  });
});

describe('WhatsAppCloudProvider (mocked Meta)', () => {
  const config = { phoneNumberId: '1234567890', accessToken: 'secret-token' };

  it('posts a template message with the parameters in order and the token in the header', async () => {
    const calls: { url: string; headers: Record<string, string>; body: unknown }[] = [];
    const provider = new WhatsAppCloudProvider(config, (url, init) => {
      calls.push({ url, headers: init.headers, body: JSON.parse(init.body) });
      return Promise.resolve({ ok: true, status: 200 });
    });

    await provider.sendTemplate({ to: '+5511987654321', templateName: 'bellohub_reminder_pt_br', languageCode: 'pt_BR', parameters: ['Ana', '10:00', 'Facial'] });

    expect(provider.enabled).toBe(true);
    expect(calls[0]?.url).toBe('https://graph.facebook.com/v21.0/1234567890/messages');
    expect(calls[0]?.headers.Authorization).toBe('Bearer secret-token');
    expect(calls[0]?.body).toEqual({
      messaging_product: 'whatsapp',
      to: '5511987654321',
      type: 'template',
      template: { name: 'bellohub_reminder_pt_br', language: { code: 'pt_BR' }, components: [{ type: 'body', parameters: [{ type: 'text', text: 'Ana' }, { type: 'text', text: '10:00' }, { type: 'text', text: 'Facial' }] }] }
    });
  });

  it('turns Meta failures into generic errors that say nothing about the message', async () => {
    const down = new WhatsAppCloudProvider(config, () => Promise.resolve({ ok: false, status: 503 }));
    const rejected = new WhatsAppCloudProvider(config, () => Promise.resolve({ ok: false, status: 400 }));
    const message = { to: '+5511987654321', templateName: 't', languageCode: 'en_US', parameters: [] };

    await expect(down.sendTemplate(message)).rejects.toMatchObject({ code: 'TRY_AGAIN' });
    await expect(rejected.sendTemplate(message)).rejects.toMatchObject({ code: 'INTERNAL' });
  });

  it('is what the messenger uses when it is the configured provider', async () => {
    const sent: unknown[] = [];
    const provider = new WhatsAppCloudProvider(config, (_url, init) => {
      sent.push(JSON.parse(init.body));
      return Promise.resolve({ ok: true, status: 200 });
    });
    const messenger = new ProviderClientMessenger(new FakeEmailProvider(), provider, true);

    await messenger.sendWhatsApp({ template: 'reminder', to: '+5511987654321', locale: 'pt-BR', parameters: { name: 'Ana', time: '10:00', service: 'Facial', professional: 'Maria', deadline: 'sexta', link: 'https://x' } });

    expect(messenger.whatsAppAvailable).toBe(true);
    expect(JSON.stringify(sent[0])).toContain('bellohub_reminder_pt_br');
  });
});

describe('push payloads (docs/11 section 7)', () => {
  it('carries a kind, an id and a localization key, and no text, name or argument', () => {
    const message = buildFcmMessage('token-123', { kind: 'booking', id: 'abc' });

    expect(message).toEqual({
      token: 'token-123',
      data: { kind: 'booking', id: 'abc' },
      apns: {
        headers: { 'apns-push-type': 'alert', 'apns-priority': '5' },
        payload: { aps: { alert: { locKey: 'push.booking.new' }, sound: 'default' } }
      }
    });
    expect(JSON.stringify(message)).not.toMatch(/loc-?args|title|body/i);
  });

  it('makes the mailbox push silent: background, no alert, no sound', () => {
    const message = buildFcmMessage('token-123', { kind: 'mailbox', id: 'item-1' });

    expect(message.apns?.headers).toEqual({ 'apns-push-type': 'background', 'apns-priority': '5' });
    expect(message.apns?.payload?.aps).toEqual({ contentAvailable: true });
  });

  it('marks a late arrival urgent', () => {
    const message = buildFcmMessage('token-123', { kind: 'bookingLate', id: 'b1' });

    expect(message.apns?.headers?.['apns-priority']).toBe('10');
    expect(message.apns?.payload?.aps.customData).toEqual({ 'interruption-level': 'time-sensitive' });
  });

  it('has a localization key for every alert kind, all under push.*', () => {
    for (const key of Object.values(PUSH_ALERT_KEYS)) expect(key).toMatch(/^push\.[a-z]+\.[A-Za-z]+$/);
  });
});
