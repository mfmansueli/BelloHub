import { describe, expect, it } from 'vitest';

import { ReferenceCode } from '../../src/contracts/common.js';
import type { Random } from '../../src/lib/random.js';
import { systemRandom } from '../../src/lib/random.js';
import { newReference, REFERENCE_ALPHABET, requestExpiry } from '../../src/lib/unverifiedRequests.js';

const fixedBytes = (values: number[]): Random => ({ ...systemRandom, bytes: () => Buffer.from(values) });

describe('newReference', () => {
  it('is five characters from an alphabet without look-alikes, and passes the contract', () => {
    for (let n = 0; n < 200; n += 1) {
      const reference = newReference(systemRandom);
      expect(reference).toHaveLength(5);
      expect(ReferenceCode.safeParse(reference).success).toBe(true);
    }
    expect(REFERENCE_ALPHABET).not.toMatch(/[01ILO]/);
    expect(new Set(REFERENCE_ALPHABET).size).toBe(31);
  });

  it('maps every byte value into the alphabet', () => {
    expect(newReference(fixedBytes([0, 30, 31, 255, 128]))).toBe(
      [0, 30, 0, 255 % 31, 128 % 31].map((index) => REFERENCE_ALPHABET[index]).join('')
    );
  });
});

describe('requestExpiry', () => {
  const now = Date.UTC(2026, 9, 1, 15, 0);

  it('is 24 hours after the request when the visit is later', () => {
    expect(requestExpiry(now, now + 72 * 3_600_000)).toBe(now + 24 * 3_600_000);
  });

  it('is the visit start when that comes first', () => {
    expect(requestExpiry(now, now + 3 * 3_600_000)).toBe(now + 3 * 3_600_000);
  });
});
