#!/usr/bin/env node
// Prints the SMS region allow-list for the human who configures Firebase Auth (docs/14-HUMAN-TASKS.md H4, D37):
// Authentication > Settings > SMS region policy > "Allow", choosing exactly these countries. It reads the region presets
// of the app (BelloHub/Resources/Regions/regions.json), the single table of markets, so the list can never drift from
// the markets the product supports. A unit test compares this output with functions/src/config/smsRegions.ts.
//
//   node firebase/scripts/sms-regions.mjs          readable list
//   node firebase/scripts/sms-regions.mjs --json   {"regions":[{"code":"BR","callingCode":"55"}, ...]}

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const file = fileURLToPath(new URL('../../BelloHub/Resources/Regions/regions.json', import.meta.url));
const regions = JSON.parse(readFileSync(file, 'utf8'))
  .map(({ code, callingCode }) => ({ code, callingCode }))
  .sort((a, b) => a.code.localeCompare(b.code));

if (process.argv.includes('--json')) {
  process.stdout.write(`${JSON.stringify({ regions })}\n`);
} else {
  process.stdout.write('Allow SMS verification codes ONLY to these countries (Firebase Auth > Settings > SMS region policy):\n');
  for (const { code, callingCode } of regions) process.stdout.write(`  ${code}  +${callingCode}\n`);
  process.stdout.write('Everything else stays blocked. The e-mail code is always offered as the fallback (D37).\n');
}
