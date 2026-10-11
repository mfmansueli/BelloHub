// Turns what a person types into E.164 (`+5511912345678`) and E.164 into the digits `wa.me` wants.
// Pure and table-tested. Accepts any digit system. Mirrors the iOS `PhoneNormalizer`
// (docs/07-LOCALIZATION.md section 2.4, docs/16-MARKETS.md section 4).

import { digitsOnly, toAsciiDigits } from './digits';
import { countryByCode } from './countries';
import { REGION_PRESETS, type RegionPreset } from './regions.generated';

export type PhoneFailure = 'empty' | 'tooShort' | 'tooLong' | 'implausibleLength';

export type PhoneResult = { ok: true; e164: string } | { ok: false; reason: PhoneFailure };

/** What the normalizer needs to know about the country the person is in. */
export interface PhoneRegion {
  readonly code: string;
  readonly callingCode: string;
  readonly nationalLengths?: readonly number[];
  readonly trunkPrefix?: string;
}

/** The region for an ISO code: a preset when the product knows it (with lengths), else the bare calling code. */
export function phoneRegion(code: string): PhoneRegion {
  const preset = REGION_PRESETS.find((candidate) => candidate.code === code.toUpperCase());
  if (preset !== undefined) return preset;
  const country = countryByCode(code);
  return { code: code.toUpperCase(), callingCode: country?.callingCode ?? '' };
}

const PRESETS_BY_CODE_LENGTH: readonly RegionPreset[] = [...REGION_PRESETS].sort(
  (a, b) => b.callingCode.length - a.callingCode.length,
);

function stripTrunk(digits: string, region: PhoneRegion): string {
  const trunk = region.trunkPrefix;
  return trunk !== undefined && digits.startsWith(trunk) ? digits.slice(trunk.length) : digits;
}

function lengthFailure(national: string, region: PhoneRegion): PhoneFailure | null {
  const lengths = region.nationalLengths;
  if (lengths === undefined || lengths.length === 0) return null;
  if (lengths.includes(national.length)) return null;
  return national.length > Math.max(...lengths) ? 'tooLong' : 'implausibleLength';
}

function validateInternational(digits: string): PhoneResult {
  if (digits.length < 8) return { ok: false, reason: 'tooShort' };
  if (digits.length > 15) return { ok: false, reason: 'tooLong' };
  const preset = PRESETS_BY_CODE_LENGTH.find((candidate) => digits.startsWith(candidate.callingCode));
  if (preset !== undefined) {
    // A trunk prefix typed after the country code (+44 0...) is dropped, as phones do.
    const national = stripTrunk(digits.slice(preset.callingCode.length), preset);
    const failure = lengthFailure(national, preset);
    if (failure !== null) return { ok: false, reason: failure };
    return { ok: true, e164: `+${preset.callingCode}${national}` };
  }
  return { ok: true, e164: `+${digits}` };
}

function validateNational(digits: string, region: PhoneRegion): PhoneResult {
  if (region.callingCode === '') return { ok: false, reason: 'implausibleLength' };
  const national = stripTrunk(digits, region);
  if (national.length < 6) return { ok: false, reason: 'tooShort' };
  const failure = lengthFailure(national, region);
  if (failure !== null) return { ok: false, reason: failure };
  if (region.callingCode.length + national.length > 15) return { ok: false, reason: 'tooLong' };
  return { ok: true, e164: `+${region.callingCode}${national}` };
}

/**
 * `region` is the professional's business region or the country the client picked. A number that starts with
 * `+` or `00` is international and ignores it.
 */
export function normalizePhone(input: string, region: PhoneRegion): PhoneResult {
  const ascii = toAsciiDigits(input.trim());
  const digits = digitsOnly(ascii);
  if (digits === '') return { ok: false, reason: 'empty' };
  if (ascii.startsWith('+')) return validateInternational(digits);
  if (digits.startsWith('00')) return validateInternational(digits.slice(2));
  return validateNational(digits, region);
}

/** Digits for `https://wa.me/<digits>`: no plus, no spaces. */
export function whatsAppDigits(e164: string): string {
  return digitsOnly(e164);
}

/** The last four digits, for "we sent a code to the number ending in 4321". */
export function lastFour(e164: string): string {
  const digits = digitsOnly(e164);
  return digits.slice(-4);
}

/** `a***@mail.com`: enough for her to recognise it, not enough to read it aloud. */
export function maskEmail(email: string): string {
  const at = email.lastIndexOf('@');
  if (at < 1) return email;
  return `${email.charAt(0)}***${email.slice(at)}`;
}
