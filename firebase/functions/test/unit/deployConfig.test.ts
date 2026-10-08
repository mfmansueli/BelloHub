import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

const read = (relative: string): unknown => JSON.parse(readFileSync(fileURLToPath(new URL(`../../../${relative}`, import.meta.url)), 'utf8'));

interface FirebaseJson {
  firestore?: { rules: string; indexes: string; location: string };
  storage?: { rules: string };
  functions?: { source: string; codebase: string }[];
  hosting?: unknown;
  emulators: Record<string, { port?: number; enabled?: boolean }>;
}

describe('what a human deploys (H4) and what the tests start', () => {
  const dev = read('firebase.json') as FirebaseJson;
  const test = read('firebase.test.json') as FirebaseJson;

  it('points the dev target at the real rules, the indexes and the functions', () => {
    expect(dev.firestore).toMatchObject({ rules: 'firestore.rules', indexes: 'firestore.indexes.json', location: 'eur3' });
    expect(dev.storage?.rules).toBe('storage.rules');
    expect(dev.functions).toEqual([expect.objectContaining({ source: 'functions', codebase: 'default' })]);
  });

  it('runs the tests on other ports than the default emulators so parallel sessions never collide', () => {
    for (const name of ['auth', 'functions', 'firestore', 'storage']) {
      expect(test.emulators[name]?.port, name).toBeDefined();
      expect(test.emulators[name]?.port, name).not.toBe(dev.emulators[name]?.port);
    }
    expect(test.firestore).toEqual(dev.firestore);
    expect(test.storage).toEqual(dev.storage);
  });

  it('keeps the Cloud Storage lifecycle backstop for sealed envelopes at 31 days (D30)', () => {
    const lifecycle = read('storage-lifecycle.json') as { rule: { action: { type: string }; condition: { age: number; matchesPrefix: string[] } }[] };

    expect(lifecycle.rule).toEqual([{ action: { type: 'Delete' }, condition: { age: 31, matchesPrefix: ['inbox/'] } }]);
  });

  it('declares Node 22 for the functions, as the docs say', () => {
    const pkg = read('functions/package.json') as { engines: { node: string }; main: string; type: string };

    expect(pkg.engines.node).toBe('22');
    expect(pkg.type).toBe('module');
    expect(pkg.main).toBe('lib/index.js');
  });
});
