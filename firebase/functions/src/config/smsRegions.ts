// The SMS region allow-list (D37, docs/11 section 12): verification codes may go only to the countries of the region
// presets. A test compares this list with BelloHub/Resources/Regions/regions.json so the two cannot drift;
// firebase/scripts/sms-regions.mjs prints it for the human who sets the Auth SMS policy (H4).

export const SMS_REGIONS: readonly { code: string; callingCode: string }[] = [
  { code: 'BR', callingCode: '55' },
  { code: 'PT', callingCode: '351' },
  { code: 'ES', callingCode: '34' },
  { code: 'MX', callingCode: '52' },
  { code: 'US', callingCode: '1' },
  { code: 'AR', callingCode: '54' },
  { code: 'CO', callingCode: '57' },
  { code: 'CL', callingCode: '56' },
  { code: 'PE', callingCode: '51' },
  { code: 'IT', callingCode: '39' },
  { code: 'FR', callingCode: '33' },
  { code: 'DE', callingCode: '49' },
  { code: 'AT', callingCode: '43' },
  { code: 'CH', callingCode: '41' },
  { code: 'GB', callingCode: '44' },
  { code: 'IE', callingCode: '353' },
  { code: 'AU', callingCode: '61' },
  { code: 'NZ', callingCode: '64' },
  { code: 'ZA', callingCode: '27' },
  { code: 'IN', callingCode: '91' },
  { code: 'TR', callingCode: '90' },
  { code: 'ID', callingCode: '62' },
  { code: 'SA', callingCode: '966' },
  { code: 'AE', callingCode: '971' }
];

export const SMS_CALLING_CODES: readonly string[] = [...new Set(SMS_REGIONS.map((region) => region.callingCode))];
