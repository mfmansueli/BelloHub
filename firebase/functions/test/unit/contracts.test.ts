import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { HttpsError } from 'firebase-functions/v2/https';
import { describe, expect, it } from 'vitest';

import { USE_CASE_NAMES, USE_CASES } from '../../src/app/registry.js';
import { SMS_CALLING_CODES, SMS_REGIONS } from '../../src/config/smsRegions.js';
import { FUNCTIONS_REGION } from '../../src/config/region.js';
import { buildSchemas } from '../../src/contracts/schemas.js';
import { ERROR_CODES, ERROR_STATUS } from '../../src/lib/errors.js';

// The contract is API.md plus the schemas: the web app and the iOS repository code against them, so a function that is
// not documented, a documented function that does not exist, or a stale schema file is a bug found here.

const root = fileURLToPath(new URL('../../', import.meta.url));
const read = (relative: string): string => readFileSync(`${root}${relative}`, 'utf8');
const api = read('API.md');
const index = read('src/index.ts');

const NOT_CALLABLE = ['onBookingWritten', 'onInboxItemCreated', 'cleanupJob', 'sendReminders', 'appStoreNotifications'];
const PLAIN_HTTP = ['getIcs'];

function backticked(line: string): string[] {
  return [...line.matchAll(/`(\w+)`/g)].map((match) => match[1] ?? '');
}

function documentedFunctions(): string[] {
  return backticked(api.slice(api.indexOf('## 11. Function index')));
}

describe('API.md and the code list the same functions', () => {
  it('documents every callable, the plain HTTP function, the triggers, jobs and webhook', () => {
    const documented = new Set(documentedFunctions());
    const expected = [...USE_CASE_NAMES, ...PLAIN_HTTP, ...NOT_CALLABLE];

    expect([...documented].sort()).toEqual([...expected].sort());
  });

  it('exports exactly those functions from index.ts, with the same names', () => {
    const exported = [...index.matchAll(/^export const (\w+) =/gm)].map((match) => match[1] ?? '');

    expect([...exported].sort()).toEqual([...USE_CASE_NAMES, ...PLAIN_HTTP, ...NOT_CALLABLE].sort());
  });

  it('describes every callable in the body of the document, not only in the index', () => {
    for (const name of USE_CASE_NAMES) {
      const mentions = api.match(new RegExp(`\\b${name}\\b`, 'g'))?.length ?? 0;
      expect(mentions, `${name} appears in API.md`).toBeGreaterThanOrEqual(2);
    }
  });

  it('has a unique name and a schema pair for every use case', () => {
    expect(new Set(USE_CASE_NAMES).size).toBe(USE_CASE_NAMES.length);
    for (const useCase of USE_CASES) {
      expect(useCase.name).toMatch(/^[a-z][A-Za-z]+$/);
      expect(['public', 'token', 'owner']).toContain(useCase.access);
    }
  });

  it('files each use case in the folder of its access level', () => {
    const folders: Record<string, string[]> = {
      owner: readdirSync(`${root}src/owner`).map((file) => file.replace('.ts', '')),
      token: readdirSync(`${root}src/token`).map((file) => file.replace('.ts', '')),
      public: readdirSync(`${root}src/public`).map((file) => file.replace('.ts', ''))
    };
    for (const useCase of USE_CASES) {
      const folder = useCase.access === 'owner' ? 'owner' : folders.token?.includes(useCase.name) ? 'token' : 'public';
      expect(folders[folder], useCase.name).toContain(useCase.name);
    }
  });
});

describe('the committed JSON schemas', () => {
  it('are up to date with the zod schemas (run npm run gen:schemas)', () => {
    const committed = JSON.parse(read('contracts/schemas.json')) as unknown;

    expect(committed).toEqual(JSON.parse(JSON.stringify(buildSchemas())));
  });

  it('forbid unknown fields in every request', () => {
    const schemas = buildSchemas();
    for (const [name, schema] of Object.entries(schemas)) {
      const input = schema.input as { type?: string; additionalProperties?: unknown };
      expect(input.type, name).toBe('object');
      expect(input.additionalProperties, name).toBe(false);
    }
  });
});

describe('error codes', () => {
  it('map to the HTTP status the SDK really sends', () => {
    for (const code of ERROR_CODES) {
      const mapped = ERROR_STATUS[code];
      const error = new HttpsError(mapped.status as ConstructorParameters<typeof HttpsError>[0], code);
      expect(error.httpErrorCode.status, code).toBe(mapped.http);
    }
  });

  it('are all explained in API.md with the same HTTP status', () => {
    const table = api.slice(api.indexOf('## 3. Error codes'), api.indexOf('## 4. Conventions'));
    for (const code of ERROR_CODES) {
      const row = table.split('\n').find((line) => line.startsWith(`| \`${code}\` |`));
      expect(row, `${code} has a row`).toBeDefined();
      expect(row, code).toContain(`| ${ERROR_STATUS[code].http} |`);
    }
  });
});

describe('configuration kept in step with the repository', () => {
  it('uses the Functions region of firebase/config/<env>.json in every environment', () => {
    for (const env of ['dev', 'staging', 'prod']) {
      const config = JSON.parse(readFileSync(`${root}../config/${env}.json`, 'utf8')) as { FUNCTIONS_REGION: string; DATA_REGION: string };
      expect(config.FUNCTIONS_REGION, env).toBe(FUNCTIONS_REGION);
      expect(config.DATA_REGION, env).toBe('eu');
    }
  });

  it('allows SMS only for the countries of regions.json (D37)', () => {
    const regions = JSON.parse(readFileSync(`${root}../../BelloHub/Resources/Regions/regions.json`, 'utf8')) as { code: string; callingCode: string }[];

    expect([...SMS_REGIONS].sort((a, b) => a.code.localeCompare(b.code))).toEqual([...regions.map(({ code, callingCode }) => ({ code, callingCode }))].sort((a, b) => a.code.localeCompare(b.code)));
    expect(new Set(SMS_CALLING_CODES).size).toBe(SMS_CALLING_CODES.length);
  });
});
