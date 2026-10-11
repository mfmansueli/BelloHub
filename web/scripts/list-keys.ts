// Prints every message key the code uses with the parameters passed at its call sites. A helper for writing and
// reviewing the catalogs: `npx tsx scripts/list-keys.ts`.

import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { findKeyUses } from './lib/i18n-keys';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../src');
const keys = new Map<string, Set<string>>();
for (const use of findKeyUses(root)) {
  const params = keys.get(use.key) ?? new Set<string>();
  for (const name of use.params ?? []) params.add(name);
  keys.set(use.key, params);
}
for (const key of [...keys.keys()].sort()) process.stdout.write(`${key}  ${[...(keys.get(key) ?? [])].sort().join(',')}\n`);
process.stdout.write(`${keys.size} keys\n`);
