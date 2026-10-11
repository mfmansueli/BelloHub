import { describe, expect, it } from 'vitest';

import { decodeBase64Url, encodeBase64Url } from '../../src/lib/base64url';
import { FSI, LRI, PDI, isolate, isolateLtr, ltr, stripIsolates } from '../../src/lib/bidi';
import { digitsOnly, toAsciiDigits } from '../../src/lib/digits';

describe('digit normalization (docs/07 section 7)', () => {
  it('turns Arabic-Indic, Extended Arabic-Indic, Devanagari and fullwidth digits into ASCII', () => {
    expect(toAsciiDigits('٠١٢٣٤٥٦٧٨٩')).toBe('0123456789');
    expect(toAsciiDigits('۰۱۲۳۴۵۶۷۸۹')).toBe('0123456789');
    expect(toAsciiDigits('०१२३४५६७८९')).toBe('0123456789');
    expect(toAsciiDigits('０１２３４５６７８９')).toBe('0123456789');
  });

  it('leaves other characters alone and maps the Arabic separators', () => {
    expect(toAsciiDigits('+٥٥ (١١) ٩٨٧٦٥-٤٣٢١')).toBe('+55 (11) 98765-4321');
    expect(toAsciiDigits('١٢٣٫٥٠')).toBe('123.50');
    expect(toAsciiDigits('١٬٢٣٤')).toBe('1,234');
    expect(toAsciiDigits('abc é ñ')).toBe('abc é ñ');
  });

  it('keeps only the digits of a code typed with spaces and a mixed script', () => {
    expect(digitsOnly('४८२ ९१६')).toBe('482916');
    expect(digitsOnly('٤٨٢-٩١٦ ')).toBe('482916');
    expect(digitsOnly('4 8 2 9 1 6')).toBe('482916');
    expect(digitsOnly('')).toBe('');
  });

  it('does not turn a surrogate pair or a combining mark into a digit', () => {
    expect(toAsciiDigits('🌿5')).toBe('🌿5');
    expect(toAsciiDigits('é')).toBe('é');
  });
});

describe('bidi isolation (docs/07 section 2.5)', () => {
  it('wraps a name so its direction cannot leak into the sentence', () => {
    expect(isolate('Maria')).toBe(`${FSI}Maria${PDI}`);
    expect(isolateLtr('15:00')).toBe(`${LRI}15:00${PDI}`);
  });

  it('wraps nothing for empty text, and strips what it wrapped', () => {
    expect(isolate('')).toBe('');
    expect(isolateLtr('')).toBe('');
    expect(stripIsolates(isolate('مريم') + isolateLtr('+55 11 98765 4321'))).toBe('مريم+55 11 98765 4321');
  });

  it('marks a value as left-to-right without changing its text', () => {
    expect(String(ltr(42))).toBe('42');
    expect(ltr('15:00').value).toBe('15:00');
  });
});

describe('base64url', () => {
  it('encodes without padding using the URL alphabet', () => {
    expect(encodeBase64Url(new Uint8Array([0xfb, 0xff, 0xfe]))).toBe('-__-');
    expect(encodeBase64Url(new Uint8Array([1]))).toBe('AQ');
    expect(encodeBase64Url(new Uint8Array([1, 2]))).toBe('AQI');
    expect(encodeBase64Url(new Uint8Array([]))).toBe('');
  });

  it('round-trips every length from 0 to 40 bytes', () => {
    for (let length = 0; length <= 40; length += 1) {
      const bytes = Uint8Array.from({ length }, (_, i) => (i * 37 + 11) % 256);
      expect(decodeBase64Url(encodeBase64Url(bytes))).toEqual(bytes);
    }
  });

  it('matches Node for random-looking data', () => {
    const bytes = Uint8Array.from({ length: 77 }, (_, i) => (i * 91 + 5) % 256);
    expect(encodeBase64Url(bytes)).toBe(Buffer.from(bytes).toString('base64url'));
  });

  it('rejects characters outside the alphabet and impossible lengths', () => {
    expect(() => decodeBase64Url('ab+d')).toThrow();
    expect(() => decodeBase64Url('ab=d')).toThrow();
    expect(() => decodeBase64Url('abcde')).toThrow();
  });
});
