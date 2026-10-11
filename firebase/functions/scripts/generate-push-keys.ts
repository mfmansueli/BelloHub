// Writes contracts/push-keys.json from PUSH_ALERT_KEYS. Run with `npm run gen:push-keys` after adding a push alert, then
// scripts/sync-server-contract.sh (the iOS tests check that the app carries a string for every key).
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { publishedPushKeys } from '../src/push/PushSender.js';

const target = fileURLToPath(new URL('../contracts/push-keys.json', import.meta.url));
writeFileSync(target, `${JSON.stringify({ keys: publishedPushKeys() }, null, 2)}\n`);
process.stdout.write(`wrote ${target}\n`);
