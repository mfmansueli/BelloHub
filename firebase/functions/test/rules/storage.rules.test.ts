import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { assertFails, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import type { RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { getBytes, ref, uploadString } from 'firebase/storage';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

// Storage holds only sealed envelopes that do not fit in Firestore. Clients never touch it: functions write and read
// with the Admin SDK (docs/11-BACKEND-FIREBASE.md section 5).

const rules = readFileSync(fileURLToPath(new URL('../../../storage.rules', import.meta.url)), 'utf8');

describe('storage.rules', () => {
  let env: RulesTestEnvironment;

  beforeAll(async () => {
    env = await initializeTestEnvironment({ projectId: 'demo-bellohub', storage: { rules } });
  });

  afterAll(async () => {
    await env.cleanup();
  });

  it('allows nothing: not even a signed-in professional on her own folder', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await uploadString(ref(context.storage(), 'inbox/alice/item-1.json'), '{"ct":"x"}');
    });
    for (const storage of [env.authenticatedContext('alice').storage(), env.unauthenticatedContext().storage()]) {
      await assertFails(getBytes(ref(storage, 'inbox/alice/item-1.json')));
      await assertFails(uploadString(ref(storage, 'inbox/alice/item-2.json'), 'x'));
      await assertFails(uploadString(ref(storage, 'anything.txt'), 'x'));
    }
  });

  it('is a single deny-all statement', () => {
    const allows = rules.replace(/\/\/.*$/gm, '').match(/allow[^;]*;/g) ?? [];
    expect(allows).toEqual(['allow read, write: if false;']);
  });
});
