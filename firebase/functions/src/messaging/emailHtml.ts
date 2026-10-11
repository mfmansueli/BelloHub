/**
 * The HTML twin of a plain-text email. Mail providers (Outlook above all) trust a message that carries both a text
 * and a simple HTML part more than a text-only one from a new sender, so every email goes out as both. It is built from
 * the same text: no template per language, no images, no tracking pixel, no styles from outside. Everything is
 * escaped, a bare http(s) address becomes a link, and a six-digit verification code is shown large.
 *
 * Branded with the web tokens (owner, 2026-10-11): ivory page, graphite text, the orange `rose-text` for links. Two
 * optional parts the text cannot express: where she works as a small box after the first paragraph, and the personal
 * link also as a button-looking link ("Change or cancel") right after the paragraph that carries it.
 */

import type { EmailPlace } from './emailPlace.js';

const ESCAPES: Record<string, string> = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

/** Web tokens (web/src/styles/tokens.generated.css), light: --ivory, --surface, --ink, --ink-2, --rose-text, --action, --on-action. */
export const EMAIL_COLORS = {
  page: '#FAFAF9',
  surface: '#FFFFFF',
  ink: '#141414',
  ink2: '#5A5A58',
  link: '#BF3E0A',
  action: '#E84A10',
  onAction: '#141414'
} as const;

export interface EmailHtmlExtras {
  place?: EmailPlace | undefined;
  /** The personal link, shown once more as a button after the paragraph that carries it. */
  action?: { label: string; url: string } | undefined;
}

export function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => ESCAPES[character] ?? character);
}

// Bidi isolates and marks are never part of an address: in Arabic text one may sit right after a link (docs/07 section 7).
const URL_PATTERN = /https?:\/\/[^\s<>"'‎‏⁦-⁩]+/g;
const TRAILING_PUNCTUATION = /[.,;:!?)\]]+$/;
const CODE_PATTERN = /(?<![\w-])\d{6}(?![\w-])/g;

function paragraphToHtml(paragraph: string): string {
  const linked = escapeHtml(paragraph).replace(URL_PATTERN, (match) => {
    const trailing = TRAILING_PUNCTUATION.exec(match)?.[0] ?? '';
    const address = trailing ? match.slice(0, match.length - trailing.length) : match;
    return `<a href="${address}" style="color:${EMAIL_COLORS.link}">${address}</a>${trailing}`;
  });
  const withCode = linked.replace(
    CODE_PATTERN,
    (code) => `<strong style="font-size:26px;letter-spacing:3px;white-space:nowrap">${code}</strong>`
  );
  return withCode.replace(/\r?\n/g, '<br>');
}

function placeHtml(place: EmailPlace): string {
  const links = place.links
    .map((link) => `<a href="${escapeHtml(link.url)}" style="color:${EMAIL_COLORS.link};font-weight:600">${escapeHtml(link.label)}</a>`)
    .join(' &nbsp;·&nbsp; ');
  return [
    `<div style="margin:0 0 16px;padding:12px 16px;background:${EMAIL_COLORS.surface};border-radius:12px">`,
    `<p style="margin:0 0 4px;font-size:13px;font-weight:600;color:${EMAIL_COLORS.ink2}">${escapeHtml(place.title)}</p>`,
    `<p style="margin:0;font-size:16px;line-height:1.5">${place.lines.map(escapeHtml).join('<br>')}</p>`,
    place.directions ? `<p style="margin:4px 0 0;font-size:14px;line-height:1.5;color:${EMAIL_COLORS.ink2}">${escapeHtml(place.directions)}</p>` : '',
    `<p style="margin:8px 0 0;font-size:15px;line-height:1.6">${links}</p>`,
    '</div>'
  ].join('');
}

function actionHtml(action: { label: string; url: string }): string {
  return (
    `<p style="margin:0 0 16px"><a href="${escapeHtml(action.url)}" style="display:inline-block;padding:12px 20px;` +
    `background:${EMAIL_COLORS.action};color:${EMAIL_COLORS.onAction};border-radius:12px;font-weight:600;text-decoration:none">` +
    `${escapeHtml(action.label)}</a></p>`
  );
}

export function emailHtml(subject: string, text: string, lang = 'en', extras: EmailHtmlExtras = {}): string {
  const blocks: string[] = [];
  text
    .trim()
    .split(/\n{2,}/)
    .forEach((paragraph, index) => {
      blocks.push(`<p style="margin:0 0 16px;font-size:16px;line-height:1.55">${paragraphToHtml(paragraph)}</p>`);
      if (index === 0 && extras.place) blocks.push(placeHtml(extras.place));
      if (extras.action && paragraph.includes(extras.action.url)) blocks.push(actionHtml(extras.action));
    });
  const direction = lang === 'ar' ? ' dir="rtl"' : '';
  return [
    '<!doctype html>',
    `<html lang="${escapeHtml(lang)}"${direction}><head><meta charset="utf-8">`,
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    `<title>${escapeHtml(subject)}</title></head>`,
    `<body style="margin:0;padding:24px 16px;background:${EMAIL_COLORS.page};color:${EMAIL_COLORS.ink};`,
    'font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Helvetica,Arial,sans-serif">',
    '<div style="max-width:480px;margin:0 auto">',
    blocks.join(''),
    `<p style="margin:24px 0 0;font-size:12px;color:${EMAIL_COLORS.ink2}">Bello Hub</p>`,
    '</div></body></html>'
  ].join('');
}
