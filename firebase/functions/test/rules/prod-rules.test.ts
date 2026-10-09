import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { assertFails, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import type { RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

// The existing Firebase project `bello-hub` may receive ONLY these rules until a human creates dev and staging (H4).
// If this test fails, someone loosened the production rules.

const read = (relative: string): string => readFileSync(fileURLToPath(new URL(relative, import.meta.url)), 'utf8');
const stripComments = (rules: string): string => rules.replace(/\/\/.*$/gm, '');

describe('production rules (firebase/rules/prod)', () => {
  const firestoreRules = read('../../../rules/prod/firestore.rules');
  const storageRules = read('../../../rules/prod/storage.rules');

  it('contains exactly one allow statement and it is "if false"', () => {
    for (const rules of [firestoreRules, storageRules]) {
      const allows = stripComments(rules).match(/allow[^;]*;/g) ?? [];
      expect(allows).toHaveLength(1);
      expect(allows[0]).toMatch(/^allow read, write: if false;$/);
    }
  });

  it('has no index and no function that could be deployed with it', () => {
    const indexes = JSON.parse(read('../../../rules/prod/firestore.indexes.json')) as { indexes: unknown[]; fieldOverrides: unknown[] };
    expect(indexes.indexes).toEqual([]);
    expect(indexes.fieldOverrides).toEqual([]);
    const prodConfig = JSON.parse(read('../../../firebase.prod.json')) as Record<string, unknown>;
    expect(Object.keys(prodConfig).sort()).toEqual(['firestore', 'storage']);
    expect(prodConfig).not.toHaveProperty('functions');
    expect(prodConfig).not.toHaveProperty('hosting');
  });

  it('points only at the deny-all files', () => {
    const prodConfig = JSON.parse(read('../../../firebase.prod.json')) as {
      firestore: { rules: string; indexes: string };
      storage: { rules: string };
    };
    expect(prodConfig.firestore.rules).toBe('rules/prod/firestore.rules');
    expect(prodConfig.firestore.indexes).toBe('rules/prod/firestore.indexes.json');
    expect(prodConfig.storage.rules).toBe('rules/prod/storage.rules');
  });
});

describe('the default project cannot reach the cloud by accident', () => {
  it('makes a demo project the default, so a bare "firebase deploy" fails', () => {
    const rc = JSON.parse(read('../../../.firebaserc')) as { projects: Record<string, string> };
    expect(rc.projects.default).toMatch(/^demo-/);
  });

  it('keeps the real project reachable only by explicit aliases (deny-all target and the dev target, D43)', () => {
    const rc = JSON.parse(read('../../../.firebaserc')) as { projects: Record<string, string> };
    expect(rc.projects['bello-hub-deny-all']).toBe('bello-hub');
    expect(rc.projects.dev).toBe('bello-hub');
    const aliases = Object.entries(rc.projects).filter(([, id]) => id === 'bello-hub').map(([alias]) => alias).sort();
    expect(aliases).toEqual(['bello-hub-deny-all', 'dev']);
  });
});

describe('the production Firestore rules behave as deny all on the emulator', () => {
  let env: RulesTestEnvironment;

  beforeAll(async () => {
    env = await initializeTestEnvironment({
      projectId: 'demo-bellohub-prod',
      firestore: { rules: read('../../../rules/prod/firestore.rules') }
    });
  });

  afterAll(async () => {
    await env.cleanup();
  });

  it('refuses reads and writes of everyone, even a signed-in professional and even her own documents', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'publicProfiles/maria'), { displayName: 'Maria' });
    });
    for (const db of [env.authenticatedContext('u1').firestore(), env.unauthenticatedContext().firestore()]) {
      await assertFails(getDoc(doc(db, 'publicProfiles/maria')));
      await assertFails(setDoc(doc(db, 'accounts/u1'), { locale: 'en' }));
    }
  });
});
