import { describe, expect, it } from 'vitest';

import { COUNTRIES, countryByCode, countryName } from '../../src/lib/countries';
import { lastFour, maskEmail, normalizePhone, phoneRegion, whatsAppDigits } from '../../src/lib/phone';
import { REGION_PRESETS } from '../../src/lib/regions.generated';

const BR = phoneRegion('BR');

describe('normalizePhone (mirrors the iOS PhoneNormalizer, docs/16 section 4)', () => {
  it('accepts the three Brazilian ways to type a mobile number and stores E.164', () => {
    const typed = ['(11) 91234-5678', '11912345678', '+55 11 91234-5678', '0 11 91234 5678', '0055 11 91234-5678'];
    for (const input of typed) {
      expect(normalizePhone(input, BR)).toEqual({ ok: true, e164: '+5511912345678' });
    }
  });

  it('accepts a landline with ten national digits', () => {
    expect(normalizePhone('(11) 3123-4567', BR)).toEqual({ ok: true, e164: '+551131234567' });
  });

  it('reads Arabic-Indic, Extended Arabic-Indic and Devanagari digits', () => {
    expect(normalizePhone('+٥٥ ١١ ٩١٢٣٤-٥٦٧٨', BR)).toEqual({ ok: true, e164: '+5511912345678' });
    expect(normalizePhone('۱۱ ۹۱۲۳۴ ۵۶۷۸', BR)).toEqual({ ok: true, e164: '+5511912345678' });
    expect(normalizePhone('११ ९१२३४ ५६७८', BR)).toEqual({ ok: true, e164: '+5511912345678' });
  });

  it('drops a trunk prefix typed after the country code, as phones do', () => {
    expect(normalizePhone('+44 07911 123456', phoneRegion('GB'))).toEqual({ ok: true, e164: '+447911123456' });
    expect(normalizePhone('07911 123456', phoneRegion('GB'))).toEqual({ ok: true, e164: '+447911123456' });
  });

  it('handles Portugal, Spain, Mexico, the United States, Germany and Saudi Arabia', () => {
    expect(normalizePhone('912 345 678', phoneRegion('PT'))).toEqual({ ok: true, e164: '+351912345678' });
    expect(normalizePhone('612 34 56 78', phoneRegion('ES'))).toEqual({ ok: true, e164: '+34612345678' });
    expect(normalizePhone('55 1234 5678', phoneRegion('MX'))).toEqual({ ok: true, e164: '+525512345678' });
    expect(normalizePhone('(415) 555-2671', phoneRegion('US'))).toEqual({ ok: true, e164: '+14155552671' });
    expect(normalizePhone('0151 23456789', phoneRegion('DE'))).toEqual({ ok: true, e164: '+4915123456789' });
    expect(normalizePhone('05 1234 5678', phoneRegion('SA'))).toEqual({ ok: true, e164: '+966512345678' });
  });

  it('keeps an international number from a country the product has no preset for', () => {
    expect(normalizePhone('+358 40 123 4567', BR)).toEqual({ ok: true, e164: '+358401234567' });
    expect(normalizePhone('+81 90 1234 5678', BR)).toEqual({ ok: true, e164: '+819012345678' });
  });

  it('uses the picked country when it is not a preset: any plausible length', () => {
    expect(normalizePhone('40 123 4567', phoneRegion('FI'))).toEqual({ ok: true, e164: '+358401234567' });
  });

  it('says why a number is refused', () => {
    expect(normalizePhone('', BR)).toEqual({ ok: false, reason: 'empty' });
    expect(normalizePhone('abc', BR)).toEqual({ ok: false, reason: 'empty' });
    expect(normalizePhone('12345', BR)).toEqual({ ok: false, reason: 'tooShort' });
    expect(normalizePhone('+55 11 912', BR)).toEqual({ ok: false, reason: 'tooShort' });
    expect(normalizePhone('+55 11 9123', BR)).toEqual({ ok: false, reason: 'implausibleLength' });
    expect(normalizePhone('1191234567890123', BR)).toEqual({ ok: false, reason: 'tooLong' });
    expect(normalizePhone('+55 11 9123 45678 9', BR)).toEqual({ ok: false, reason: 'tooLong' });
    expect(normalizePhone('1234567', BR)).toEqual({ ok: false, reason: 'implausibleLength' });
  });

  it('every preset accepts a number of its first national length typed in that region', () => {
    for (const preset of REGION_PRESETS) {
      const length = preset.nationalLengths[0] ?? 9;
      const national = '9'.repeat(length);
      expect(normalizePhone(national, preset)).toEqual({ ok: true, e164: `+${preset.callingCode}${national}` });
      expect(normalizePhone(`+${preset.callingCode}${national}`, BR)).toEqual({ ok: true, e164: `+${preset.callingCode}${national}` });
    }
  });
});

describe('phone helpers', () => {
  it('gives wa.me digits without the plus', () => {
    expect(whatsAppDigits('+5511912345678')).toBe('5511912345678');
  });

  it('shows the last four digits and masks an email', () => {
    expect(lastFour('+5511987654321')).toBe('4321');
    expect(maskEmail('anna@mail.com')).toBe('a***@mail.com');
    expect(maskEmail('nope')).toBe('nope');
  });
});

describe('country table', () => {
  it('has a calling code for every preset and no duplicate country', () => {
    for (const preset of REGION_PRESETS) {
      expect(countryByCode(preset.code)?.callingCode).toBe(preset.callingCode);
    }
    const codes = COUNTRIES.map((country) => country.code);
    expect(new Set(codes).size).toBe(codes.length);
    expect(codes.length).toBeGreaterThan(200);
  });

  it('names countries through Intl.DisplayNames in the reader language', () => {
    expect(countryName('BR', 'en')).toBe(new Intl.DisplayNames(['en'], { type: 'region' }).of('BR'));
    expect(countryName('BR', 'ar')).toBe(new Intl.DisplayNames(['ar'], { type: 'region' }).of('BR'));
    expect(countryName('BR', 'pt-BR')).toBe('Brasil');
  });
});
