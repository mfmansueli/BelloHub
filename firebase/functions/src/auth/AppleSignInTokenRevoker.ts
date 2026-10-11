import { createPrivateKey, sign } from 'node:crypto';
import type { KeyObject } from 'node:crypto';

import { base64url } from '../lib/crypto.js';
import type { Logger } from '../lib/log.js';
import type { AppleRevocationOutcome, AppleTokenRevoker } from './AppleTokenRevoker.js';

export interface AppleSignInConfig {
  /** The Apple Developer team (fixed for Bello Hub). */
  teamId: string;
  /** The Services ID or app bundle id the sign-in happened with (the app's bundle id for a native sign-in). */
  clientId: string;
  /** The key id shown under Certificates, Identifiers & Profiles > Keys (`APPLE_SIGNIN_KEY_ID`). */
  keyId: string;
  /** The `.p8` contents, PEM (Secret Manager `APPLE_SIGNIN_PRIVATE_KEY`). */
  privateKeyPem: string;
  tokenEndpoint?: string | undefined;
  revokeEndpoint?: string | undefined;
}

export type FetchLike = (url: string, init: { method: string; headers: Record<string, string>; body: string }) => Promise<{
  ok: boolean;
  status: number;
  json(): Promise<unknown>;
}>;

const TOKEN_ENDPOINT = 'https://appleid.apple.com/auth/token';
const REVOKE_ENDPOINT = 'https://appleid.apple.com/auth/revoke';
const APPLE_AUDIENCE = 'https://appleid.apple.com';
/** Apple allows up to six months; a secret that lives for the request alone is enough. */
const CLIENT_SECRET_TTL_SECONDS = 5 * 60;

/**
 * Revokes a Sign in with Apple grant through Apple's REST API (D44): the authorization code the app just obtained is
 * exchanged at `/auth/token` for a refresh token, which is revoked at `/auth/revoke`. Both calls authenticate with a
 * client secret: an ES256 JWT signed with the team's Sign in with Apple key. The class logs outcomes only, never the
 * code, the tokens or the key, and it never throws: the deletion of her data must not depend on Apple being up.
 */
export class AppleSignInTokenRevoker implements AppleTokenRevoker {
  readonly configured = true;
  private readonly key: KeyObject;
  private readonly tokenEndpoint: string;
  private readonly revokeEndpoint: string;

  constructor(
    private readonly config: AppleSignInConfig,
    private readonly fetchFn: FetchLike = fetch,
    private readonly now: () => number = () => Date.now(),
    private readonly log?: Logger
  ) {
    this.key = createPrivateKey(config.privateKeyPem);
    this.tokenEndpoint = config.tokenEndpoint ?? TOKEN_ENDPOINT;
    this.revokeEndpoint = config.revokeEndpoint ?? REVOKE_ENDPOINT;
  }

  /** The adapter when the key id and the key are set and the key parses; otherwise nothing (keep the unconfigured one). */
  static ifConfigured(
    config: { teamId: string; clientId: string; keyId: string; privateKeyPem: string },
    fetchFn?: FetchLike,
    log?: Logger
  ): AppleSignInTokenRevoker | undefined {
    const keyId = config.keyId.trim();
    const privateKeyPem = config.privateKeyPem.trim();
    if (!keyId || !privateKeyPem) return undefined;
    try {
      return new AppleSignInTokenRevoker({ ...config, keyId, privateKeyPem }, fetchFn, undefined, log);
    } catch {
      log?.error('apple.revoker.badKey', { reason: 'unparseable' });
      return undefined;
    }
  }

  async revoke(authorizationCode: string): Promise<AppleRevocationOutcome> {
    try {
      const secret = this.clientSecret();
      const exchanged = await this.post(this.tokenEndpoint, {
        client_id: this.config.clientId,
        client_secret: secret,
        grant_type: 'authorization_code',
        code: authorizationCode
      });
      if (!exchanged.ok) {
        this.log?.info('apple.revoke.exchangeRefused', { httpStatus: exchanged.status });
        return 'failed';
      }
      const body = (await exchanged.json()) as { refresh_token?: unknown; access_token?: unknown };
      const token = typeof body.refresh_token === 'string' ? body.refresh_token : typeof body.access_token === 'string' ? body.access_token : undefined;
      if (!token) {
        this.log?.info('apple.revoke.exchangeRefused', { reason: 'no_token' });
        return 'failed';
      }
      const revoked = await this.post(this.revokeEndpoint, {
        client_id: this.config.clientId,
        client_secret: secret,
        token,
        token_type_hint: typeof body.refresh_token === 'string' ? 'refresh_token' : 'access_token'
      });
      if (!revoked.ok) {
        this.log?.info('apple.revoke.refused', { httpStatus: revoked.status });
        return 'failed';
      }
      return 'revoked';
    } catch (error) {
      this.log?.info('apple.revoke.unreachable', { reason: (error as Error).name });
      return 'failed';
    }
  }

  /** Apple's client secret: `{ alg: ES256, kid }` over `{ iss: team, iat, exp, aud, sub: client }`, signed with the .p8 key. */
  clientSecret(): string {
    const issuedAt = Math.floor(this.now() / 1000);
    const header = { alg: 'ES256', kid: this.config.keyId };
    const claims = {
      iss: this.config.teamId,
      iat: issuedAt,
      exp: issuedAt + CLIENT_SECRET_TTL_SECONDS,
      aud: APPLE_AUDIENCE,
      sub: this.config.clientId
    };
    const signingInput = `${base64url(Buffer.from(JSON.stringify(header), 'utf8'))}.${base64url(Buffer.from(JSON.stringify(claims), 'utf8'))}`;
    // JWS wants the raw r||s signature, not DER.
    const signature = sign('sha256', Buffer.from(signingInput, 'utf8'), { key: this.key, dsaEncoding: 'ieee-p1363' });
    return `${signingInput}.${base64url(signature)}`;
  }

  private post(url: string, form: Record<string, string>): ReturnType<FetchLike> {
    return this.fetchFn(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
      body: new URLSearchParams(form).toString()
    });
  }
}
