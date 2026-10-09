import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { C } from '../../src/lib/docs.js';

// firestore.indexes.json is deployed by a human (H4). These checks keep it consistent with what the code queries and with
// the retention promises, without needing a cloud project.

interface Indexes {
  indexes: { collectionGroup: string; queryScope: string; fields: { fieldPath: string; order: string }[] }[];
  fieldOverrides: { collectionGroup: string; fieldPath: string; ttl?: boolean; indexes: { order?: string; queryScope: string }[] }[];
}

const file = JSON.parse(readFileSync(fileURLToPath(new URL('../../../firestore.indexes.json', import.meta.url)), 'utf8')) as Indexes;

describe('firestore.indexes.json', () => {
  it('has the one composite index the calendar queries need: bookings by owner and start', () => {
    expect(file.indexes).toEqual([
      {
        collectionGroup: 'bookings',
        queryScope: 'COLLECTION',
        fields: [
          { fieldPath: 'ownerUid', order: 'ASCENDING' },
          { fieldPath: 'startsAt', order: 'ASCENDING' }
        ]
      }
    ]);
  });

  it('puts a TTL policy on every short-lived collection and on the sealed items (D30), as a backstop to the cleanup job', () => {
    const ttl = file.fieldOverrides.filter((override) => override.ttl).map((override) => `${override.collectionGroup}.${override.fieldPath}`);

    expect(ttl.sort()).toEqual(
      [C.items, C.holds, C.emailCodes, C.emailProofs, C.rate, C.idempotency, C.audit, C.waitlist, C.portal].map((name) => `${name}.expiresAt`).sort()
    );
  });

  it('lets the cleanup job query sealed items across all mailboxes (a collection group index)', () => {
    const items = file.fieldOverrides.find((override) => override.collectionGroup === 'items');

    expect(items?.indexes.some((index) => index.queryScope === 'COLLECTION_GROUP')).toBe(true);
  });

  it('never puts a TTL on bookings or accounts: those are deleted by code that also removes what hangs off them', () => {
    const names = file.fieldOverrides.filter((override) => override.ttl).map((override) => override.collectionGroup);

    expect(names).not.toContain('bookings');
    expect(names).not.toContain('accounts');
  });
});
