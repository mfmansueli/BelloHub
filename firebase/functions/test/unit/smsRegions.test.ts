import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { SMS_REGIONS } from '../../src/config/smsRegions.js';

const script = fileURLToPath(new URL('../../../scripts/sms-regions.mjs', import.meta.url));

describe('firebase/scripts/sms-regions.mjs (D37)', () => {
  it('prints exactly the countries the server tells the web app SMS may go to', () => {
    const output = JSON.parse(execFileSync('node', [script, '--json'], { encoding: 'utf8' })) as { regions: { code: string; callingCode: string }[] };

    expect(output.regions).toEqual([...SMS_REGIONS].sort((a, b) => a.code.localeCompare(b.code)));
  });

  it('prints a readable list for the human who sets the Auth policy', () => {
    const output = execFileSync('node', [script], { encoding: 'utf8' });

    expect(output).toContain('BR  +55');
    expect(output).toContain('PT  +351');
    expect(output).toContain('SA  +966');
    expect(output).toMatch(/e-mail code is always offered/);
  });
});
