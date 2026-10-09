import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { Timestamp } from 'firebase-admin/firestore';
import { describe, expect, it } from 'vitest';

import { cleanText } from '../../src/lib/sanitize.js';
import { clientIpFrom } from '../../src/lib/clientIp.js';
import { ALLOWED_ORIGINS } from '../../src/http/callable.js';
import { base64url, base64urlByteLength, fromBase64url, inboxKeyId, keyedHash, safeEqualHex, sha256Hex } from '../../src/lib/crypto.js';
import type { InboxKeyringEntry, WaitlistDoc } from '../../src/lib/docs.js';
import { acceptsKey, applyInboxKey, currentKey, isKnownKey, KEY_GRACE_MS, keyringView, nextPruneAt, pruneKeyring } from '../../src/lib/keyring.js';
import type { KeyApplied } from '../../src/lib/keyring.js';
import { createLogger, MemoryLogSink, scrubFields } from '../../src/lib/log.js';
import { matchesWaitlist } from '../../src/lib/waitlistMatch.js';
import { planFromTransaction, shouldReplacePlan } from '../../src/billing/plan.js';
import { buildSchemas } from '../../src/contracts/schemas.js';

describe('cleanText', () => {
  it('normalizes, trims and removes control and invisible characters', () => {
    const control = String.fromCharCode(0);
    const bidi = String.fromCharCode(0x202e);
    const zeroWidth = String.fromCharCode(0x200b);

    expect(cleanText(`  Mar${control}ia ${bidi}Souza${zeroWidth}  `, false)).toBe('Maria Souza');
    expect(cleanText('á', false)).toBe('á'); // NFC: a + combining acute becomes one character
  });

  it('turns line breaks into spaces for single-line fields and keeps them for text areas', () => {
    expect(cleanText('one\ntwo\r\nthree', false)).toBe('one two three');
    expect(cleanText('one\ntwo\r\nthree\r', true)).toBe('one\ntwo\nthree');
  });

  it('keeps Arabic, Devanagari, accents and emoji intact', () => {
    for (const text of ['ماريا سوزا', 'मारिया सूज़ा', 'João da Conceição', 'Müller-Lüdenscheidt', 'İlker', 'Ana 🌸']) {
      expect(cleanText(text, false)).toBe(text);
    }
  });
});

describe('clientIpFrom (a forged header must not dodge a rate limit)', () => {
  it('counts from the end by the number of trusted proxies', () => {
    expect(clientIpFrom('1.1.1.1, 2.2.2.2, 3.3.3.3', undefined, 1)).toBe('3.3.3.3');
    expect(clientIpFrom('1.1.1.1, 2.2.2.2, 3.3.3.3', undefined, 2)).toBe('2.2.2.2');
    expect(clientIpFrom('9.9.9.9', undefined, 1)).toBe('9.9.9.9');
  });

  it('ignores what the client put before the proxy\'s entry', () => {
    expect(clientIpFrom('6.6.6.6, 203.0.113.9', undefined, 1)).toBe('203.0.113.9');
  });

  it('falls back to the socket and then to "unknown"', () => {
    expect(clientIpFrom(undefined, '10.0.0.1', 1)).toBe('10.0.0.1');
    expect(clientIpFrom('', undefined, 1)).toBe('unknown');
  });
});

describe('CORS allow-list (only our own Hosting sites, not every Firebase site)', () => {
  const allowed = (origin: string): boolean => ALLOWED_ORIGINS.some((rule) => (typeof rule === 'string' ? rule === origin : rule.test(origin)));

  it('accepts the product domain, its subdomains and the Hosting sites of our projects, previews included', () => {
    for (const origin of [
      'https://bellohub.app',
      'https://www.bellohub.app',
      'https://bello-hub.web.app',
      'https://bellohub.web.app',
      'https://bello-hub--pr-12-abc123.web.app',
      'https://bellohub-staging.firebaseapp.com'
    ]) {
      expect(allowed(origin), origin).toBe(true);
    }
  });

  it('refuses other sites, plain http and look-alike domains', () => {
    for (const origin of [
      'https://evil.web.app',
      'https://notbellohub.web.app',
      'https://anything.firebaseapp.com',
      'http://bellohub.app',
      'https://bellohub.app.attacker.com',
      'https://xbellohub.app'
    ]) {
      expect(allowed(origin), origin).toBe(false);
    }
  });
});

describe('crypto helpers', () => {
  it('hashes with a key and a label so a phone hash can never equal an email hash', () => {
    expect(keyedHash('pepper', 'phone', 'x')).not.toBe(keyedHash('pepper', 'email', 'x'));
    expect(keyedHash('pepper', 'phone', 'x')).not.toBe(keyedHash('other', 'phone', 'x'));
    expect(keyedHash('pepper', 'phone', 'x')).toMatch(/^[0-9a-f]{64}$/);
    expect(sha256Hex('abc')).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  it('computes the inbox key id as the first 8 bytes of SHA-256 of the key (docs/06 section 3.2)', () => {
    const raw = Buffer.alloc(32, 7);

    expect(inboxKeyId(base64url(raw))).toBe(base64url(createHash('sha256').update(raw).digest().subarray(0, 8)));
    expect(inboxKeyId(base64url(raw))).toHaveLength(11);
    expect(inboxKeyId('too-short')).toBeNull();
  });

  it('compares in constant time and decodes only base64url', () => {
    expect(safeEqualHex('abcd', 'abcd')).toBe(true);
    expect(safeEqualHex('abcd', 'abce')).toBe(false);
    expect(safeEqualHex('abcd', 'abc')).toBe(false);
    expect(fromBase64url('not base64!')).toBeNull();
    expect(base64urlByteLength('A'.repeat(43))).toBe(32);
  });
});

describe('keyring (D51)', () => {
  const HOUR = 3_600_000;
  const DAY = 24 * HOUR;
  const entry = (keyId: string, retired = false): InboxKeyringEntry => ({
    keyId, pub: keyId, createdAt: Timestamp.fromMillis(1), ...(retired ? { retiredAt: Timestamp.fromMillis(2) } : {})
  });
  const ok = (applied: ReturnType<typeof applyInboxKey>): KeyApplied => {
    if ('failure' in applied) throw new Error(applied.failure);
    return applied;
  };

  it('adds a first key, ignores the same key again, and rotates to a new one keeping the old', () => {
    const first = ok(applyInboxKey([], { keyId: 'k1', pub: 'p1' }, 10));
    expect(first.changed).toBe(true);
    expect(ok(applyInboxKey(first.keyring, { keyId: 'k1', pub: 'p1' }, 20)).changed).toBe(false);

    const rotated = ok(applyInboxKey(first.keyring, { keyId: 'k2', pub: 'p2' }, 30));
    expect(rotated.keyring.map((k) => [k.keyId, k.retiredAt !== undefined])).toEqual([['k1', true], ['k2', false]]);
    expect(currentKey(rotated.keyring)?.keyId).toBe('k2');
    expect(isKnownKey(rotated.keyring, 'k1')).toBe(true);
    expect(isKnownKey(rotated.keyring, 'zz')).toBe(false);
  });

  it('makes an older key current again without duplicating it', () => {
    const back = ok(applyInboxKey([entry('k1', true), entry('k2')], { keyId: 'k1', pub: 'k1' }, 50));

    expect(back.keyring.map((k) => [k.keyId, k.retiredAt !== undefined])).toEqual([['k1', false], ['k2', true]]);
  });

  it('accepts envelopes for a retired key for 24 hours, then only for the current one', () => {
    const t0 = Date.UTC(2026, 9, 1);
    const ring = ok(applyInboxKey(ok(applyInboxKey([], { keyId: 'k1', pub: 'p1' }, t0 - DAY)).keyring, { keyId: 'k2', pub: 'p2' }, t0)).keyring;

    expect(acceptsKey(ring, 'k2', t0)).toBe(true);
    expect(acceptsKey(ring, 'k1', t0)).toBe(true);
    expect(acceptsKey(ring, 'k1', t0 + KEY_GRACE_MS - 1)).toBe(true);
    expect(acceptsKey(ring, 'k1', t0 + KEY_GRACE_MS)).toBe(false);
    expect(acceptsKey(ring, 'k2', t0 + 400 * DAY)).toBe(true);
    expect(acceptsKey(ring, 'zz', t0)).toBe(false);
    expect(keyringView(ring).find((k) => k.keyId === 'k1')?.acceptsUntil?.toMillis()).toBe(t0 + KEY_GRACE_MS);
  });

  it('closes a compromised key at once and never lets it come back', () => {
    const t0 = Date.UTC(2026, 9, 1);
    const ring = ok(applyInboxKey([entry('k1')], { keyId: 'k2', pub: 'p2' }, t0, { compromised: true })).keyring;

    expect(acceptsKey(ring, 'k1', t0)).toBe(false);
    expect(acceptsKey(ring, 'k2', t0)).toBe(true);
    expect(ring[0]?.compromisedAt?.toMillis()).toBe(t0);
    expect(keyringView(ring)[0]?.acceptsUntil?.toMillis()).toBe(t0);
    expect(applyInboxKey(ring, { keyId: 'k1', pub: 'k1' }, t0 + HOUR)).toEqual({ failure: 'compromisedKey' });
    // The flag is about the key being replaced: a rotation without it leaves no mark on the new key.
    expect(ring[1]?.compromisedAt).toBeUndefined();
  });

  it('drops a retired key once the grace and the 30 day envelope life are over, and says when to look again', () => {
    const t0 = Date.UTC(2026, 9, 1);
    const ring = ok(applyInboxKey([entry('k1')], { keyId: 'k2', pub: 'p2' }, t0)).keyring;
    const death = t0 + KEY_GRACE_MS + 30 * DAY;

    expect(nextPruneAt(ring)).toBe(death);
    expect(pruneKeyring(ring, death - 1).map((k) => k.keyId)).toEqual(['k1', 'k2']);
    expect(pruneKeyring(ring, death).map((k) => k.keyId)).toEqual(['k2']);
    expect(nextPruneAt(pruneKeyring(ring, death))).toBeUndefined();
    // A rotation prunes on the way, and a compromised key dies 24 hours earlier.
    expect(ok(applyInboxKey(ring, { keyId: 'k3', pub: 'p3' }, death)).keyring.map((k) => k.keyId)).toEqual(['k2', 'k3']);
    const closed = ok(applyInboxKey([entry('k1')], { keyId: 'k2', pub: 'p2' }, t0, { compromised: true })).keyring;
    expect(nextPruneAt(closed)).toBe(t0 + 30 * DAY);
  });
});

describe('logging', () => {
  it('keeps ids, labels and numbers and drops everything else', () => {
    const sink = new MemoryLogSink();
    const log = createLogger(sink);

    log.info('booking.created', { bookingId: 'abc123', kind: 'bookingLink', count: 3 });
    log.info('x', { code: 'Maria Souza' });
    log.info('y', { ownerUid: 'ana@example.com' });
    log.info('z', { bookingId: '+5511987654321' });
    log.info('w', { itemId: 'eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIn0.sig' });
    // Callers cannot do this in TypeScript; a JavaScript caller or a bad cast still must not leak.
    const loose = log as unknown as { info(event: string, fields: object): void };
    loose.info('free.text', { note: 'allergic to latex', name: 'Ana', phone: '+55', count: 'many' });

    expect(sink.entries[0]).toEqual({ severity: 'INFO', event: 'booking.created', fields: { bookingId: 'abc123', kind: 'bookingLink', count: 3 } });
    expect(sink.entries[1]?.fields).toEqual({ code: '[redacted]' });
    expect(sink.entries[2]?.fields).toEqual({ ownerUid: '[redacted]' });
    expect(sink.entries[3]?.fields).toEqual({ bookingId: '[redacted]' });
    expect(sink.entries[4]?.fields).toEqual({ itemId: '[redacted]' });
    expect(JSON.stringify(sink.entries[5])).not.toMatch(/latex|Ana|\+55/);
    expect(sink.entries[5]?.fields).toEqual({ dropped: 'unknown-field' });
  });

  it('refuses an event name that is not a plain identifier', () => {
    const sink = new MemoryLogSink();

    createLogger(sink).info('Booking for Maria Souza', {});

    expect(sink.entries[0]?.event).toBe('invalid-event');
  });

  it('drops non-finite numbers and objects', () => {
    expect(scrubFields({ count: Number.NaN, durationMs: 12 })).toEqual({ durationMs: 12 });
  });
});

describe('waitlist matching (mirrors the iOS WaitlistMatcher)', () => {
  const entry = (id: string, over: Partial<WaitlistDoc>): WaitlistDoc & { id: string } => ({
    id, ownerUid: 'o', slug: 's', name: 'N', phone: '+1', phoneHash: 'h', locale: 'en', dayFrom: '2026-10-01', dayTo: '2026-10-07',
    status: 'waiting', createdAt: Timestamp.fromMillis(1000), expiresAt: Timestamp.fromMillis(9e12), ...over
  });
  const minutes = new Map([['facial', 60], ['long', 120]]);

  it('takes people still waiting whose days include the freed day, first come first served', () => {
    const matches = matchesWaitlist(
      [
        entry('late', { createdAt: Timestamp.fromMillis(3000) }),
        entry('early', { createdAt: Timestamp.fromMillis(1000) }),
        entry('offered', { status: 'offered' }),
        entry('elsewhere', { dayFrom: '2026-10-09', dayTo: '2026-10-10' })
      ],
      '2026-10-03', 90, minutes
    );

    expect(matches.map((m) => m.id)).toEqual(['early', 'late']);
  });

  it('skips a service that does not fit in the freed time and keeps one that does or has no service', () => {
    const matches = matchesWaitlist(
      [entry('fits', { serviceId: 'facial' }), entry('too-long', { serviceId: 'long' }), entry('any', {}), entry('unknown', { serviceId: 'gone' })],
      '2026-10-03', 60, minutes
    );

    expect(matches.map((m) => m.id).sort()).toEqual(['any', 'fits', 'unknown']);
  });

  it('includes both ends of the range', () => {
    expect(matchesWaitlist([entry('a', {})], '2026-10-01', 60, minutes)).toHaveLength(1);
    expect(matchesWaitlist([entry('a', {})], '2026-10-07', 60, minutes)).toHaveLength(1);
    expect(matchesWaitlist([entry('a', {})], '2026-10-08', 60, minutes)).toHaveLength(0);
  });
});

describe('plan from a verified purchase', () => {
  const NOW = 1_000_000;
  const tx = (over: object) => ({ productId: 'p', bundleId: 'b', environment: 'Production' as const, ...over });

  it('is active until the paid period ends, in grace while Apple retries, then expired', () => {
    expect(planFromTransaction(tx({ expiresAt: NOW + 1 }), NOW)).toEqual({ state: 'active', expiresAt: NOW + 1 });
    expect(planFromTransaction(tx({ expiresAt: NOW - 1, gracePeriodExpiresAt: NOW + 5 }), NOW)).toEqual({ state: 'grace', expiresAt: NOW + 5 });
    expect(planFromTransaction(tx({ expiresAt: NOW - 1 }), NOW)).toEqual({ state: 'expired', expiresAt: NOW - 1 });
  });

  it('lets a refund win over everything', () => {
    expect(planFromTransaction(tx({ expiresAt: NOW + 99, revokedAt: NOW - 1 }), NOW).state).toBe('revoked');
  });

  it('replaces a plan only with one that runs at least as long, except a revoke', () => {
    expect(shouldReplacePlan({ state: 'none' }, { state: 'expired' })).toBe(true);
    expect(shouldReplacePlan({ state: 'active', expiresAt: 100 }, { state: 'active', expiresAt: 50 })).toBe(false);
    expect(shouldReplacePlan({ state: 'active', expiresAt: 100 }, { state: 'active', expiresAt: 100 })).toBe(true);
    expect(shouldReplacePlan({ state: 'active', expiresAt: 100 }, { state: 'revoked', expiresAt: 1 })).toBe(true);
  });
});

describe('source hygiene (docs/11 section 9, docs/13 section 4)', () => {
  const sourceDir = fileURLToPath(new URL('../../src/', import.meta.url));

  function files(dir: string): string[] {
    return readdirSync(dir).flatMap((name) => {
      const path = `${dir}${name}`;
      return statSync(path).isDirectory() ? files(`${path}/`) : path.endsWith('.ts') ? [path] : [];
    });
  }

  const sources = files(sourceDir).map((path) => ({ path: path.replace(sourceDir, ''), text: readFileSync(path, 'utf8') }));

  it('has source to check', () => {
    expect(sources.length).toBeGreaterThan(60);
  });

  it('never calls console or the Cloud Functions logger outside the single scrubbing sink', () => {
    for (const { path, text } of sources) {
      expect(text, path).not.toMatch(/\bconsole\./);
      if (path !== 'lib/cloudLogSink.ts') expect(text, path).not.toMatch(/firebase-functions\/logger|functions\.logger/);
      expect(text, path).not.toMatch(/process\.std(out|err)/);
    }
  });

  it('keeps analytics out', () => {
    for (const { path, text } of sources) expect(text, path).not.toMatch(/analytics|crashlytics|sentry|mixpanel|segment\.com/i);
  });

  it('never opens an envelope: no decryption primitive anywhere', () => {
    for (const { path, text } of sources) {
      expect(text, path).not.toMatch(/createDecipher|privateDecrypt|subtle\.decrypt|chacha20-poly1305/i);
    }
  });

  it('has no financial vocabulary (docs/01 rule 1): no payment, invoice, deposit or commission in the server', () => {
    for (const { path, text } of sources) {
      const withoutBilling = text.replace(/StoreKit|App Store|appStore|AppStore/g, '');
      expect(withoutBilling, path).not.toMatch(/\b(invoice|deposit|commission|checkout|stripe|paypal|chargeCard)\b/i);
    }
  });

  it('registers every callable once and nothing else reads request bodies into logs', () => {
    expect(Object.keys(buildSchemas()).length).toBeGreaterThan(40);
    for (const { path, text } of sources) {
      if (path === 'index.ts') continue;
      expect(text, path).not.toMatch(/log\.(info|warn|error|debug)\([^)]*request\.data/);
    }
  });
});
