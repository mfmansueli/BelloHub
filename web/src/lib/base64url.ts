// base64url without padding (RFC 4648 section 5), the encoding of every binary field in the sealed envelope.

const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
const LOOKUP: Record<string, number> = {};
for (let i = 0; i < ALPHABET.length; i += 1) {
  LOOKUP[ALPHABET.charAt(i)] = i;
}

export function encodeBase64Url(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i += 3) {
    const b0 = bytes[i] ?? 0;
    const b1 = bytes[i + 1] ?? 0;
    const b2 = bytes[i + 2] ?? 0;
    const triple = (b0 << 16) | (b1 << 8) | b2;
    out += ALPHABET.charAt((triple >> 18) & 63) + ALPHABET.charAt((triple >> 12) & 63);
    if (i + 1 < bytes.length) out += ALPHABET.charAt((triple >> 6) & 63);
    if (i + 2 < bytes.length) out += ALPHABET.charAt(triple & 63);
  }
  return out;
}

/** Throws on characters outside the alphabet or an impossible length, so a corrupt key never seals anything. */
export function decodeBase64Url(text: string): Uint8Array {
  if (text.length % 4 === 1) throw new Error('invalid base64url length');
  const out = new Uint8Array(Math.floor((text.length * 3) / 4));
  let o = 0;
  for (let i = 0; i < text.length; i += 4) {
    let triple = 0;
    let count = 0;
    for (let j = 0; j < 4 && i + j < text.length; j += 1) {
      const value = LOOKUP[text.charAt(i + j)];
      if (value === undefined) throw new Error('invalid base64url character');
      triple = (triple << 6) | value;
      count += 1;
    }
    triple <<= 6 * (4 - count);
    if (count >= 2) out[o++] = (triple >> 16) & 255;
    if (count >= 3) out[o++] = (triple >> 8) & 255;
    if (count === 4) out[o++] = triple & 255;
  }
  return out;
}
