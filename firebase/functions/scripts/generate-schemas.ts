// Writes contracts/schemas.json from the zod schemas. Run with `npm run gen:schemas` after changing a contract.
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { buildSchemas } from '../src/contracts/schemas.js';

const target = fileURLToPath(new URL('../contracts/schemas.json', import.meta.url));
writeFileSync(target, `${JSON.stringify(buildSchemas(), null, 2)}\n`);
process.stdout.write(`wrote ${target}\n`);
