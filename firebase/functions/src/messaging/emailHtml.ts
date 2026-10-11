/**
 * The HTML twin of a plain-text email. Mail providers (Outlook above all) trust a message that carries both a text
 * and a simple HTML part more than a text-only one from a new sender, so every email goes out as both. It is built from
 * the same text: no template per language, no images, no tracking pixel, no styles from outside. Everything is
 * escaped, a bare http(s) address becomes a link, and a six-digit verification code is shown large.
 */

const ESCAPES: Record<string, string> = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

export function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => ESCAPES[character] ?? character);
}

const URL_PATTERN = /https?:\/\/[^\s<>"']+/g;
const TRAILING_PUNCTUATION = /[.,;:!?)\]]+$/;
const CODE_PATTERN = /(?<![\w-])\d{6}(?![\w-])/g;

function paragraphToHtml(paragraph: string): string {
  const linked = escapeHtml(paragraph).replace(URL_PATTERN, (match) => {
    const trailing = TRAILING_PUNCTUATION.exec(match)?.[0] ?? '';
    const address = trailing ? match.slice(0, match.length - trailing.length) : match;
    return `<a href="${address}" style="color:#B53A0B">${address}</a>${trailing}`;
  });
  const withCode = linked.replace(
    CODE_PATTERN,
    (code) => `<strong style="font-size:26px;letter-spacing:3px;white-space:nowrap">${code}</strong>`
  );
  return withCode.replace(/\r?\n/g, '<br>');
}

export function emailHtml(subject: string, text: string, lang = 'en'): string {
  const paragraphs = text
    .trim()
    .split(/\n{2,}/)
    .map((paragraph) => `<p style="margin:0 0 16px;font-size:16px;line-height:1.55">${paragraphToHtml(paragraph)}</p>`)
    .join('');
  return [
    '<!doctype html>',
    `<html lang="${escapeHtml(lang)}"><head><meta charset="utf-8">`,
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    `<title>${escapeHtml(subject)}</title></head>`,
    '<body style="margin:0;padding:24px 16px;background:#FAF7F1;color:#272522;',
    'font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Helvetica,Arial,sans-serif">',
    '<div style="max-width:480px;margin:0 auto">',
    paragraphs,
    '<p style="margin:24px 0 0;font-size:12px;color:#625F59">Bello Hub</p>',
    '</div></body></html>'
  ].join('');
}
