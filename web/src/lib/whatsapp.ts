// "Message <Name>": a wa.me link with the text ready. The page opens it; the client taps send (D14, D31).

import { whatsAppDigits } from './phone';

export function whatsAppUrl(e164: string | undefined, text: string): string | null {
  if (e164 === undefined) return null;
  const digits = whatsAppDigits(e164);
  if (digits.length < 8) return null;
  return `https://wa.me/${digits}?text=${encodeURIComponent(text)}`;
}
