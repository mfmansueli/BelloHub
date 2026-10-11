import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { LOCALES } from '../../src/contracts/common.js';
import { DisabledEmailProvider } from '../../src/messaging/DisabledEmailProvider.js';
import { DisabledWhatsAppProvider } from '../../src/messaging/DisabledWhatsAppProvider.js';
import { EMAIL_TEMPLATE_IDS, emailLabelsFor, emailTextsFor } from '../../src/messaging/emailTemplates.js';
import { ProviderClientMessenger } from '../../src/messaging/ProviderClientMessenger.js';
import { fillTemplate, formatWhen, isolate } from '../../src/messaging/render.js';
import { emailHtml } from '../../src/messaging/emailHtml.js';
import { ResendEmailProvider } from '../../src/messaging/ResendEmailProvider.js';
import { WhatsAppCloudProvider } from '../../src/messaging/WhatsAppCloudProvider.js';
import { WHATSAPP_LANGUAGE, WHATSAPP_TEMPLATES, whatsAppTemplateName } from '../../src/messaging/whatsAppTemplates.js';
import { buildFcmMessage } from '../../src/push/fcmMessage.js';
import { BOOKING_PUSH_EVENTS, PUSH_ALERT_KEYS, publishedPushKeys } from '../../src/push/PushSender.js';
import type { PushMessage } from '../../src/push/PushSender.js';
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

// S11: every template renders in every localization with real values, nothing left unfilled, the values isolated
// only in Arabic and the date written in the reader's language.
describe('email templates rendered in every localization', () => {
  const when = Date.parse('2026-10-08T13:00:00.000Z');

  it.each(LOCALES)('%s renders all templates completely', (locale) => {
    const texts = emailTextsFor(locale);
    const vars = { code: '123456', professional: 'Maria', service: 'Glow', when: formatWhen(when, 'Europe/Lisbon', locale), link: 'https://x/m/t' };
    for (const id of EMAIL_TEMPLATE_IDS) {
      const subject = fillTemplate(texts[id].subject, vars, locale);
      const body = fillTemplate(texts[id].body, vars, locale);
      expect(`${subject} ${body}`).not.toMatch(/\{\w+\}|\bundefined\b|\bnull\b/);
      expect(body.includes('\u2068')).toBe(locale === 'ar' && /\{\w+\}/.test(texts[id].body));
    }
    expect(vars.when).not.toMatch(/2026-10/);
    if (locale === 'ar' || locale === 'hi') expect(vars.when).toMatch(/[0-9]/);
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

  it('never isolates the link: it stands on its own line, and an isolate next to it would join the detected link', () => {
    expect(fillTemplate('رابطك:\n{link}', { link: 'https://bellohub.app/m/abc' }, 'ar')).toBe('رابطك:\nhttps://bellohub.app/m/abc');
  });

  it.each(LOCALES)('%s puts every link of every email body on a line of its own', (locale) => {
    const texts = emailTextsFor(locale);
    for (const id of EMAIL_TEMPLATE_IDS) {
      const body = texts[id].body;
      if (!body.includes('{link}')) continue;
      expect(body).toMatch(/(^|\n)\{link\}(\n|$)/);
    }
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

  const place = {
    lines: ['Rua Augusta 1200', 'São Paulo 01304-001'],
    directions: '2º andar',
    maps: {
      apple: 'https://maps.apple.com/?address=Rua%20Augusta%201200',
      google: 'https://www.google.com/maps/search/?api=1&query=Rua%20Augusta%201200'
    }
  };

  it('adds where she works after the first paragraph, each map link alone on its line, and the button in the HTML', async () => {
    const provider = new FakeEmailProvider();
    const messenger = new ProviderClientMessenger(provider, new DisabledWhatsAppProvider(), true);
    const link = 'https://bellohub.app/m/AbCdEfGhIjKlMnOpQrStUv';

    await messenger.sendEmail({
      template: 'bookingConfirmed', to: 'ana@example.com', locale: 'pt-BR',
      vars: { professional: 'Maria', service: 'Facial', when: 'sábado', link }, place, manageLink: link
    });

    const sent = provider.sent[0];
    const paragraphs = (sent?.text ?? '').split('\n\n');
    expect(paragraphs[0]).toBe('Facial com Maria: sábado.');
    expect(paragraphs[1]).toBe(
      `Onde\nRua Augusta 1200\nSão Paulo 01304-001\n2º andar\nMapas da Apple:\n${place.maps.apple}\nGoogle Maps:\n${place.maps.google}`
    );
    expect(sent?.text).toContain(`\n${link}\n`);
    expect(sent?.html).toContain(`<a href="${place.maps.apple}"`);
    expect(sent?.html).toContain('>Remarcar ou cancelar</a>');
    expect(sent?.html?.indexOf('Remarcar ou cancelar</a>')).toBeGreaterThan(sent?.html?.indexOf(`>${link}</a>`) ?? Infinity);
  });

  it('sends no place and no button when there is none to send', async () => {
    const provider = new FakeEmailProvider();
    const messenger = new ProviderClientMessenger(provider, new DisabledWhatsAppProvider(), true);

    await messenger.sendEmail({ template: 'bookingDeclined', to: 'ana@example.com', locale: 'en', vars: { professional: 'Maria', service: 'Facial', when: 'Saturday', link: 'https://bellohub.app/maria' } });

    expect(provider.sent[0]?.text).not.toMatch(/Where|Maps/);
    expect(provider.sent[0]?.html).not.toContain('Change or cancel');
  });

  it.each(LOCALES)('%s has the place heading, both map names and the button label', (locale) => {
    const labels = emailLabelsFor(locale);
    for (const value of Object.values(labels)) expect(value.trim().length).toBeGreaterThan(0);
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
      data: { kind: 'booking', id: 'abc', event: 'new' },
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

  it.each([
    [{ kind: 'booking', id: 'b1', event: 'new' }, 'push.booking.new'],
    [{ kind: 'booking', id: 'b1', event: 'request' }, 'push.booking.request'],
    [{ kind: 'booking', id: 'b1', event: 'moved' }, 'push.booking.moved'],
    [{ kind: 'booking', id: 'b1', event: 'cancelled' }, 'push.booking.cancelled'],
    [{ kind: 'bookingLate', id: 'b1' }, 'push.booking.late'],
    [{ kind: 'bookingConfirmed', id: 'b1' }, 'push.booking.clientConfirmed'],
    [{ kind: 'rescheduleRequest', id: 'r1' }, 'push.reschedule.request'],
    [{ kind: 'waitlist', id: '' }, 'push.waitlist.new']
  ] satisfies [PushMessage, string][])('says what happened: %j raises %s, with no text or argument', (input, key) => {
    const message = buildFcmMessage('token-123', input);

    expect(message.apns?.payload?.aps.alert).toEqual({ locKey: key });
    expect(Object.keys(message.data ?? {}).sort()).toEqual(input.kind === 'booking' ? ['event', 'id', 'kind'] : ['id', 'kind']);
    expect(message.data?.kind).toBe(input.kind);
    expect(message.data?.id).toBe(input.id);
    expect(JSON.stringify(message)).not.toMatch(/loc-?args|title|body/i);
  });

  it('keeps the old meaning for a booking push without an event', () => {
    const message = buildFcmMessage('token-123', { kind: 'booking', id: 'b1' });

    expect(message.data?.event).toBe('new');
    expect(message.apns?.payload?.aps.alert).toEqual({ locKey: 'push.booking.new' });
  });

  it('has a key for every booking event, and only one per alert', () => {
    for (const event of BOOKING_PUSH_EVENTS) expect(PUSH_ALERT_KEYS[`booking.${event}`]).toBe(`push.booking.${event}`);
    expect(publishedPushKeys()).toHaveLength(Object.keys(PUSH_ALERT_KEYS).length);
  });

  it('publishes the key list the app checks its strings against (run npm run gen:push-keys)', () => {
    const committed = JSON.parse(readFileSync(fileURLToPath(new URL('../../contracts/push-keys.json', import.meta.url)), 'utf8')) as unknown;

    expect(committed).toEqual({ keys: publishedPushKeys() });
  });
});

describe('emailHtml (the HTML part of every email)', () => {
  it('escapes everything, so a name can never inject markup', () => {
    const html = emailHtml('Hi <b>', 'Ana <script>alert(1)</script> & "co"');
    expect(html).not.toContain('<script>');
    expect(html).toContain('&lt;script&gt;');
    expect(html).toContain('&amp;');
    expect(html).toContain('<title>Hi &lt;b&gt;</title>');
  });

  it('links a bare address without its trailing punctuation, and keeps line breaks', () => {
    const html = emailHtml('Visit', 'Friday 10:00.\nOpen https://bellohub.app/m/abc123.');
    expect(html).toContain('<a href="https://bellohub.app/m/abc123"');
    expect(html).toContain('</a>.');
    expect(html).toContain('Friday 10:00.<br>Open');
  });

  it('keeps bidi isolates and marks out of the link (Arabic text puts one right after it)', () => {
    const html = emailHtml('موعد', 'رابطك:\n\u2068https://bellohub.app/m/abc\u2069\u200f');
    expect(html).toContain('<a href="https://bellohub.app/m/abc"');
    expect(html).not.toMatch(/href="[^"]*[\u200e\u200f\u2066-\u2069]/);
  });

  it('shows a six-digit verification code large and leaves other numbers alone', () => {
    const html = emailHtml('Code', 'Your code is 272545. It lasts 10 minutes. Order 1234567.');
    expect(html).toContain('<strong style="font-size:26px;letter-spacing:3px;white-space:nowrap">272545</strong>');
    expect(html).toContain('10 minutes');
    expect(html).not.toContain('>1234567</strong>');
  });

  it('writes Arabic right to left', () => {
    expect(emailHtml('موعد', 'نص', 'ar')).toContain('<html lang="ar" dir="rtl">');
    expect(emailHtml('Visit', 'Text', 'en')).not.toContain('dir=');
  });

  it('escapes the place and the button too', () => {
    const html = emailHtml('Visit', 'Hi.\n\nYour link:\nhttps://x/m/t', 'en', {
      place: { title: 'Where <b>', lines: ['Rua <i>1</i>'], links: [{ label: 'Maps "x"', url: 'https://maps.apple.com/?address=a' }] },
      action: { label: 'Change & cancel', url: 'https://x/m/t' }
    });
    expect(html).not.toContain('<b>');
    expect(html).not.toContain('<i>');
    expect(html).toContain('Change &amp; cancel');
    expect(html).toContain('Maps &quot;x&quot;');
  });

  it('carries the language, no images and no remote styles', () => {
    const html = emailHtml('Código', 'Olá.', 'pt-BR');
    expect(html).toContain('<html lang="pt-BR">');
    expect(html).not.toMatch(/<img|<link|<script|url\(/);
  });
});

describe('ResendEmailProvider (mocked vendor, H7)', () => {
  const config = { apiKey: 're_secret', from: 'Bello Hub <no-reply@bellohub.app>' };
  const message = { to: 'ana@example.com', subject: 'Your visit', text: 'Friday 10:00. https://bellohub.app/m/x' };

  it('posts one message, text and HTML, with the key in the header and the sender from the configuration', async () => {
    const calls: { url: string; headers: Record<string, string>; body: unknown }[] = [];
    const provider = new ResendEmailProvider(config, (url, init) => {
      calls.push({ url, headers: init.headers, body: JSON.parse(init.body) });
      return Promise.resolve({ ok: true, status: 200 });
    });

    await provider.send(message);

    expect(calls[0]?.url).toBe('https://api.resend.com/emails');
    expect(calls[0]?.headers).toEqual({ Authorization: 'Bearer re_secret', 'Content-Type': 'application/json' });
    expect(calls[0]?.body).toEqual({
      from: config.from,
      to: ['ana@example.com'],
      subject: 'Your visit',
      text: message.text,
      html: emailHtml('Your visit', message.text)
    });
  });

  it('turns vendor failures into generic errors: retry on 429 and 5xx, give up on the rest, never quoting the message', async () => {
    const outcomes = await Promise.all(
      [429, 503, 400, 401].map(async (status): Promise<{ code: string; message: string }> => {
        try {
          await new ResendEmailProvider(config, () => Promise.resolve({ ok: false, status })).send(message);
          return { code: 'none', message: '' };
        } catch (error: unknown) {
          return error as { code: string; message: string };
        }
      })
    );

    expect(outcomes.map((error) => error.code)).toEqual(['TRY_AGAIN', 'TRY_AGAIN', 'INTERNAL', 'INTERNAL']);
    for (const error of outcomes) expect(error.message).not.toContain('ana@');
  });

  it('sends Reply-To only when EMAIL_REPLY_TO is set, and the HTML the messenger built', async () => {
    const bodies: Record<string, unknown>[] = [];
    const fetchFn = (_url: string, init: { body: string }) => {
      bodies.push(JSON.parse(init.body) as Record<string, unknown>);
      return Promise.resolve({ ok: true, status: 200 });
    };
    await ResendEmailProvider.ifConfigured({ ...config, replyTo: ' maria@studio.example ' }, fetchFn)?.send({ ...message, html: '<p>x</p>' });
    await ResendEmailProvider.ifConfigured({ ...config, replyTo: '' }, fetchFn)?.send(message);

    expect(bodies[0]?.reply_to).toBe('maria@studio.example');
    expect(bodies[0]?.html).toBe('<p>x</p>');
    expect(bodies[1]).not.toHaveProperty('reply_to');
  });

  it('exists only when both the key and the sender are set, so createDeps keeps email disabled otherwise', () => {
    expect(ResendEmailProvider.ifConfigured({ apiKey: '', from: config.from })).toBeUndefined();
    expect(ResendEmailProvider.ifConfigured({ apiKey: 're_x', from: '  ' })).toBeUndefined();
    expect(ResendEmailProvider.ifConfigured({ apiKey: 're_x', from: config.from })).toBeInstanceOf(ResendEmailProvider);
  });

  it('is what the messenger uses when it is the configured provider', async () => {
    const bodies: unknown[] = [];
    const provider = new ResendEmailProvider(config, (_url, init) => {
      bodies.push(JSON.parse(init.body));
      return Promise.resolve({ ok: true, status: 200 });
    });
    const messenger = new ProviderClientMessenger(provider, undefined, true);

    await messenger.sendEmail({ template: 'verificationCode', to: 'ana@example.com', locale: 'en', vars: { code: '123456', professional: 'Maria' } });

    expect(messenger.emailAvailable).toBe(true);
    expect(bodies[0]).toMatchObject({ to: ['ana@example.com'] });
    expect(JSON.stringify(bodies[0])).toContain('123456');
  });
});
