// Unicode isolates keep a name, phone number, time or URL from scrambling the text around it in right-to-left
// languages (docs/07-LOCALIZATION.md section 2.5 and 7). Same marks as the iOS `BidiIsolate`.

export const FSI = '⁨'; // first strong isolate
export const LRI = '⁦'; // left-to-right isolate
export const PDI = '⁩'; // pop directional isolate

/** Isolates `text`, letting its own first strong character decide its direction (names). */
export function isolate(text: string): string {
  return text === '' ? text : `${FSI}${text}${PDI}`;
}

/** Isolates `text` as left-to-right (phone numbers, times, URLs, codes), even inside Arabic. */
export function isolateLtr(text: string): string {
  return text === '' ? text : `${LRI}${text}${PDI}`;
}

/** Removes the isolate marks, for places where they must not appear (a copied link, a `wa.me` digit string). */
export function stripIsolates(text: string): string {
  return text.replace(/[⁦⁧⁨⁩]/g, '');
}

/** A value that a message template must show left-to-right, whatever the surrounding language. */
export class Ltr {
  constructor(readonly value: string) {}
  toString(): string {
    return this.value;
  }
}

export function ltr(value: string | number): Ltr {
  return new Ltr(String(value));
}
