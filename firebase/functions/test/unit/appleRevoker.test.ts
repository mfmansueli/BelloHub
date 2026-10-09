import { generateKeyPairSync, verify } from 'node:crypto';

import { describe, expect, it } from 'vitest';

import { AppleSignInTokenRevoker } from '../../src/auth/AppleSignInTokenRevoker.js';
import type { FetchLike } from '../../src/auth/AppleSignInTokenRevoker.js';
import { UnconfiguredAppleTokenRevoker } from '../../src/auth/UnconfiguredAppleTokenRevoker.js';
import { createLogger, MemoryLogSink } from '../../src/lib/log.js';

// The Sign in with Apple revocation adapter (D44) against a fake Apple: the client secret it signs, the two calls it
// makes, and that it never throws and never logs a code, a token or the key.

const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const PEM = privateKey.export({ format: 'pem', type: 'pkcs8' }).toString();
const CONFIG = { teamId: 'X5392U638Q', clientId: 'com.bellohub', keyId: 'ABC123DEFG', privateKeyPem: PEM };
const NOW = 1_760_000_000_000;
const CODE = 'c1a2b3c4d5e6f7a8b9c0.0.rrrr.authorization-code-from-the-app';

interface Seen {
  url: string;
  form: URLSearchParams;
}

function fakeApple(answers: { exchange?: { status: number; body?: unknown }; revoke?: { status: number } } = {}): { fetchFn: FetchLike; seen: Seen[] } {
  const seen: Seen[] = [];
  const fetchFn: FetchLike = (url, init) => {
    seen.push({ url, form: new URLSearchParams(init.body) });
    expect(init.method).toBe('POST');
    expect(init.headers['Content-Type']).toBe('application/x-www-form-urlencoded');
    if (url.endsWith('/auth/token')) {
      const status = answers.exchange?.status ?? 200;
      const body = answers.exchange?.body ?? { access_token: 'at-xyz', refresh_token: 'rt-secret-123', token_type: 'Bearer' };
      return Promise.resolve({ ok: status < 300, status, json: () => Promise.resolve(body) });
    }
    const status = answers.revoke?.status ?? 200;
    return Promise.resolve({ ok: status < 300, status, json: () => Promise.resolve({}) });
  };
  return { fetchFn, seen };
}

function decode(part: string): Record<string, unknown> {
  return JSON.parse(Buffer.from(part, 'base64url').toString('utf8')) as Record<string, unknown>;
}

describe('AppleSignInTokenRevoker', () => {
  it('signs an ES256 client secret Apple accepts: kid in the header, team as issuer, client id as subject, short life', () => {
    const revoker = new AppleSignInTokenRevoker(CONFIG, fakeApple().fetchFn, () => NOW);

    const secret = revoker.clientSecret();
    const [header, claims, signature] = secret.split('.');

    expect(decode(header ?? '')).toEqual({ alg: 'ES256', kid: 'ABC123DEFG' });
    expect(decode(claims ?? '')).toEqual({
      iss: 'X5392U638Q',
      sub: 'com.bellohub',
      aud: 'https://appleid.apple.com',
      iat: Math.floor(NOW / 1000),
      exp: Math.floor(NOW / 1000) + 300
    });
    const ok = verify('sha256', Buffer.from(`${header}.${claims}`, 'utf8'), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(signature ?? '', 'base64url'));
    expect(ok).toBe(true);
  });

  it('exchanges the authorization code for a refresh token and revokes that token', async () => {
    const apple = fakeApple();
    const revoker = new AppleSignInTokenRevoker(CONFIG, apple.fetchFn, () => NOW);

    expect(await revoker.revoke(CODE)).toBe('revoked');

    expect(apple.seen.map((call) => call.url)).toEqual(['https://appleid.apple.com/auth/token', 'https://appleid.apple.com/auth/revoke']);
    const exchange = apple.seen[0]?.form;
    expect(exchange?.get('grant_type')).toBe('authorization_code');
    expect(exchange?.get('code')).toBe(CODE);
    expect(exchange?.get('client_id')).toBe('com.bellohub');
    expect(exchange?.get('client_secret')?.split('.')).toHaveLength(3);
    const revoke = apple.seen[1]?.form;
    expect(revoke?.get('token')).toBe('rt-secret-123');
    expect(revoke?.get('token_type_hint')).toBe('refresh_token');
    expect(revoke?.get('client_secret')).toBe(exchange?.get('client_secret'));
  });

  it('falls back to the access token when Apple returns no refresh token', async () => {
    const apple = fakeApple({ exchange: { status: 200, body: { access_token: 'at-only' } } });
    const revoker = new AppleSignInTokenRevoker(CONFIG, apple.fetchFn, () => NOW);

    expect(await revoker.revoke(CODE)).toBe('revoked');
    expect(apple.seen[1]?.form.get('token')).toBe('at-only');
    expect(apple.seen[1]?.form.get('token_type_hint')).toBe('access_token');
  });

  it('reports failed, never throws, when the exchange is refused, the revocation is refused, the body is empty or Apple is down', async () => {
    const refused = new AppleSignInTokenRevoker(CONFIG, fakeApple({ exchange: { status: 400, body: { error: 'invalid_grant' } } }).fetchFn, () => NOW);
    expect(await refused.revoke(CODE)).toBe('failed');

    const noToken = new AppleSignInTokenRevoker(CONFIG, fakeApple({ exchange: { status: 200, body: {} } }).fetchFn, () => NOW);
    expect(await noToken.revoke(CODE)).toBe('failed');

    const revokeFailed = fakeApple({ revoke: { status: 500 } });
    expect(await new AppleSignInTokenRevoker(CONFIG, revokeFailed.fetchFn, () => NOW).revoke(CODE)).toBe('failed');
    expect(revokeFailed.seen).toHaveLength(2);

    const down: FetchLike = () => Promise.reject(new TypeError('fetch failed'));
    expect(await new AppleSignInTokenRevoker(CONFIG, down, () => NOW).revoke(CODE)).toBe('failed');
  });

  it('logs outcomes only: never the code, a token, the secret or the key', async () => {
    const logs = new MemoryLogSink();
    const apple = fakeApple({ revoke: { status: 400 } });
    const revoker = new AppleSignInTokenRevoker(CONFIG, apple.fetchFn, () => NOW, createLogger(logs));

    await revoker.revoke(CODE);
    await new AppleSignInTokenRevoker(CONFIG, () => Promise.reject(new Error('boom')), () => NOW, createLogger(logs)).revoke(CODE);

    expect(logs.entries.length).toBeGreaterThanOrEqual(2);
    const text = JSON.stringify(logs.entries);
    expect(text).not.toContain(CODE);
    expect(text).not.toContain('rt-secret-123');
    expect(text).not.toContain('PRIVATE KEY');
    expect(text).not.toMatch(/eyJ/);
  });

  it('is built only when the key id and the key are set and the key parses', () => {
    expect(AppleSignInTokenRevoker.ifConfigured({ ...CONFIG, keyId: '' })).toBeUndefined();
    expect(AppleSignInTokenRevoker.ifConfigured({ ...CONFIG, privateKeyPem: '  ' })).toBeUndefined();
    expect(AppleSignInTokenRevoker.ifConfigured({ ...CONFIG, privateKeyPem: 'not a key' })).toBeUndefined();
    expect(AppleSignInTokenRevoker.ifConfigured(CONFIG)?.configured).toBe(true);
  });

  it('skips when unconfigured, so a deletion never waits on Apple', async () => {
    const revoker = new UnconfiguredAppleTokenRevoker();
    expect(revoker.configured).toBe(false);
    expect(await revoker.revoke()).toBe('skipped');
  });
});
