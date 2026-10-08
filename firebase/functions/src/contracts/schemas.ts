import { z } from 'zod';

import { USE_CASES } from '../app/registry.js';

export interface FunctionSchema {
  access: 'public' | 'token' | 'owner';
  input: unknown;
  output: unknown;
}

/**
 * JSON Schema (draft 2020-12) of every callable's request and response, generated from the zod schemas the server
 * validates with. Committed as `functions/contracts/schemas.json` (`npm run gen:schemas`) so the web and iOS sides can
 * generate their types from it; a test fails when the committed file is stale.
 */
export function buildSchemas(): Record<string, FunctionSchema> {
  const result: Record<string, FunctionSchema> = {};
  for (const useCase of [...USE_CASES].sort((a, b) => a.name.localeCompare(b.name))) {
    result[useCase.name] = {
      access: useCase.access,
      input: slim(z.toJSONSchema(useCase.input, { io: 'input', unrepresentable: 'any' })),
      output: slim(z.toJSONSchema(useCase.output, { io: 'output', unrepresentable: 'any' }))
    };
  }
  return result;
}

/** zod spells `date-time` as a very long calendar regex; `format` already says it, so the regex is dropped. */
function slim<T>(schema: T): T {
  if (Array.isArray(schema)) return schema.map((item) => slim(item as unknown)) as T;
  if (typeof schema !== 'object' || schema === null) return schema;
  const entries = Object.entries(schema as Record<string, unknown>);
  const isDate = entries.some(([key, value]) => key === 'format' && value === 'date-time');
  return Object.fromEntries(entries.filter(([key]) => !(isDate && key === 'pattern')).map(([key, value]) => [key, slim(value)])) as T;
}
