// Digits typed by the client in any script become ASCII before they are sent or validated
// (docs/07-LOCALIZATION.md sections 2.4 and 7). Same blocks as the iOS `DigitNormalizer`.

/** First code point of each ten-digit block that maps to 0 through 9. */
const ZEROES = [
  0x0660, // Arabic-Indic
  0x06f0, // Extended Arabic-Indic (Persian, Urdu)
  0x0966, // Devanagari
  0xff10, // Fullwidth
] as const;

export function toAsciiDigits(text: string): string {
  let result = '';
  for (const char of text) {
    const code = char.codePointAt(0) ?? 0;
    const block = ZEROES.find((zero) => code >= zero && code < zero + 10);
    if (block !== undefined) {
      result += String(code - block);
    } else if (code === 0x066b) {
      result += '.'; // Arabic decimal separator
    } else if (code === 0x066c) {
      result += ','; // Arabic thousands separator
    } else {
      result += char;
    }
  }
  return result;
}

/** Only the ASCII digits of `text`, after normalizing every other script's digits. */
export function digitsOnly(text: string): string {
  return toAsciiDigits(text).replace(/[^0-9]/g, '');
}
