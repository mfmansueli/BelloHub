import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { VerificationException, VerificationStatus } from '@apple/app-store-server-library';
import type { JWSRenewalInfoDecodedPayload, JWSTransactionDecodedPayload, ResponseBodyV2DecodedPayload } from '@apple/app-store-server-library';
import { describe, expect, it } from 'vitest';

import { AppleAppStoreVerifier } from '../../src/billing/AppleAppStoreVerifier.js';
import type { SignedDataVerifierLike } from '../../src/billing/AppleAppStoreVerifier.js';
import { loadAppleRootCertificates } from '../../src/billing/appleRootCertificates.js';

// What can be checked without Apple's certificates: how the adapter is switched on, and how it maps what the library
// decodes (or throws) onto the plan model. The signature check itself is the library's, exercised only with real
// payloads in the sandbox (H14).

const CONFIG = { bundleId: 'com.bellohub', environment: 'Sandbox' as const };
const NOW = 1_700_000_000_000;

function transaction(over: Partial<JWSTransactionDecodedPayload> = {}): JWSTransactionDecodedPayload {
  return {
    bundleId: 'com.bellohub',
    productId: 'com.bellohub.pro.monthly',
    environment: 'Sandbox',
    appAccountToken: 'ABCDEF12-3456-4789-8ABC-DEF123456789',
    expiresDate: NOW + 86_400_000,
    ...over
  };
}

/** A stand-in for Apple's verifier: answers from a table, or throws what it is told. */
function fakeLibrary(answers: {
  transactions?: Record<string, JWSTransactionDecodedPayload | Error>;
  renewals?: Record<string, JWSRenewalInfoDecodedPayload | Error>;
  notifications?: Record<string, ResponseBodyV2DecodedPayload | Error>;
}): SignedDataVerifierLike {
  const answer = <T>(table: Record<string, T | Error> | undefined, key: string): Promise<T> => {
    const found = table?.[key];
    if (found === undefined) return Promise.reject(new VerificationException(VerificationStatus.VERIFICATION_FAILURE));
    return found instanceof Error ? Promise.reject(found) : Promise.resolve(found);
  };
  return {
    verifyAndDecodeTransaction: (jws) => answer(answers.transactions, jws),
    verifyAndDecodeRenewalInfo: (jws) => answer(answers.renewals, jws),
    verifyAndDecodeNotification: (jws) => answer(answers.notifications, jws)
  };
}

describe('loadAppleRootCertificates (H14 switch)', () => {
  it('is empty for a missing, blank or certificate-less directory', () => {
    expect(loadAppleRootCertificates('')).toEqual([]);
    expect(loadAppleRootCertificates('/nonexistent/apple-certs')).toEqual([]);
    const dir = mkdtempSync(join(tmpdir(), 'bellohub-certs-'));
    try {
      writeFileSync(join(dir, 'README.md'), 'not a certificate');
      expect(loadAppleRootCertificates(dir)).toEqual([]);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it('reads every .cer and .der file, in name order', () => {
    const dir = mkdtempSync(join(tmpdir(), 'bellohub-certs-'));
    try {
      writeFileSync(join(dir, 'b.cer'), Buffer.from([2]));
      writeFileSync(join(dir, 'a.DER'), Buffer.from([1]));
      writeFileSync(join(dir, 'notes.txt'), 'x');
      expect(loadAppleRootCertificates(dir).map((buffer) => buffer[0])).toEqual([1, 2]);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it('refuses to build the real verifier without a certificate', () => {
    expect(() => AppleAppStoreVerifier.create({ ...CONFIG, rootCertificates: [] })).toThrow();
  });
});

describe('AppleAppStoreVerifier: a decoded transaction becomes the plan model', () => {
  it('maps the dates, the account token and the product, and reports the configured environment', async () => {
    const verifier = new AppleAppStoreVerifier(CONFIG, fakeLibrary({ transactions: { 'jws-1': transaction({ revocationDate: NOW - 1 }) } }));

    const verified = await verifier.verifyTransaction('jws-1');

    expect(verified).toEqual({
      productId: 'com.bellohub.pro.monthly',
      bundleId: 'com.bellohub',
      appAccountToken: 'ABCDEF12-3456-4789-8ABC-DEF123456789',
      expiresAt: NOW + 86_400_000,
      revokedAt: NOW - 1,
      gracePeriodExpiresAt: undefined,
      environment: 'Sandbox'
    });
    expect(verifier.configured).toBe(true);
  });

  it('refuses another bundle id, another environment or a transaction without a product, even if the library let it through', async () => {
    const verifier = new AppleAppStoreVerifier(
      CONFIG,
      fakeLibrary({
        transactions: {
          'other-app': transaction({ bundleId: 'com.other' }),
          production: transaction({ environment: 'Production' }),
          'no-product': transaction({ productId: undefined })
        }
      })
    );

    for (const jws of ['other-app', 'production', 'no-product']) {
      await expect(verifier.verifyTransaction(jws), jws).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
    }
  });

  it('turns a failed signature into VERIFICATION_FAILED and a retryable failure into TRY_AGAIN, never leaking the cause', async () => {
    const verifier = new AppleAppStoreVerifier(
      CONFIG,
      fakeLibrary({
        transactions: {
          retry: new VerificationException(VerificationStatus.RETRYABLE_VERIFICATION_FAILURE, new Error('ocsp timeout')),
          chain: new VerificationException(VerificationStatus.INVALID_CERTIFICATE),
          crash: new TypeError('unexpected')
        }
      })
    );

    await expect(verifier.verifyTransaction('retry')).rejects.toMatchObject({ code: 'TRY_AGAIN' });
    await expect(verifier.verifyTransaction('chain')).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
    await expect(verifier.verifyTransaction('crash')).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
    await expect(verifier.verifyTransaction('unknown')).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
    const caught: unknown = await verifier.verifyTransaction('retry').catch((error: unknown) => error);
    expect((caught as Error).message).not.toContain('ocsp');
  });
});

describe('AppleAppStoreVerifier: a notification carries its transaction and renewal info', () => {
  it('verifies the inner transaction and renewal payloads and takes the grace period from the renewal', async () => {
    const verifier = new AppleAppStoreVerifier(
      CONFIG,
      fakeLibrary({
        notifications: {
          'note-1': { notificationType: 'DID_FAIL_TO_RENEW', subtype: 'GRACE_PERIOD', data: { signedTransactionInfo: 'tx-1', signedRenewalInfo: 'renew-1' } }
        },
        transactions: { 'tx-1': transaction({ expiresDate: NOW - 1 }) },
        renewals: { 'renew-1': { gracePeriodExpiresDate: NOW + 1000 } }
      })
    );

    const notification = await verifier.verifyNotification('note-1');

    expect(notification.type).toBe('DID_FAIL_TO_RENEW');
    expect(notification.subtype).toBe('GRACE_PERIOD');
    expect(notification.transaction).toMatchObject({ expiresAt: NOW - 1, gracePeriodExpiresAt: NOW + 1000 });
  });

  it('returns only the type for a notification without a transaction, and fails when the inner payload fails', async () => {
    const verifier = new AppleAppStoreVerifier(
      CONFIG,
      fakeLibrary({
        notifications: {
          test: { notificationType: 'TEST' },
          broken: { notificationType: 'DID_RENEW', data: { signedTransactionInfo: 'missing' } }
        }
      })
    );

    expect(await verifier.verifyNotification('test')).toEqual({ type: 'TEST', subtype: undefined });
    await expect(verifier.verifyNotification('broken')).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
    await expect(verifier.verifyNotification('nope')).rejects.toMatchObject({ code: 'VERIFICATION_FAILED' });
  });
});
