// Text from the outside world, made safe to store and to show (docs/11 section 3: "sanitized"). Pure and tested.
//  - normalized to NFC so one name has one spelling;
//  - control characters removed (a name never needs them);
//  - zero-width and bidi override characters removed: they can disguise a name or a link, and the apps isolate text
//    themselves when they draw it (docs/07 section 7).

function isInvisible(code: number): boolean {
  return (
    (code >= 0x200b && code <= 0x200f) ||
    (code >= 0x202a && code <= 0x202e) ||
    (code >= 0x2060 && code <= 0x2064) ||
    (code >= 0x2066 && code <= 0x2069) ||
    code === 0xfeff
  );
}

function isControl(code: number): boolean {
  return code < 0x20 || (code >= 0x7f && code <= 0x9f) || code === 0x2028 || code === 0x2029;
}

/** `multiline` keeps line feeds (a bio, a rules text); otherwise they become spaces. Result is trimmed. */
export function cleanText(value: string, multiline: boolean): string {
  const unified = value.normalize('NFC').replace(/\r\n?/g, '\n');
  let result = '';
  for (const character of unified) {
    const code = character.codePointAt(0) ?? 0;
    if (isInvisible(code)) continue;
    if (code === 0x0a && multiline) result += '\n';
    else if (isControl(code)) result += multiline ? '' : ' ';
    else result += character;
  }
  return result.trim();
}
