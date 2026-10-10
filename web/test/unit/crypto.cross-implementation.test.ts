// "Someone else's decryption" (docs/06 section 11 item 5): what the browser's code seals is opened by Python
// (pyhpke + cryptography), a different implementation, in a separate process.

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

import { encodeBase64Url } from '../../src/lib/base64url';
import { framePlaintext, sealPayload } from '../../src/crypto/seal';
import type { SealedEnvelope } from '../../src/api/types';
import { decodeBase64Url } from '../../src/lib/base64url';
import { inboxKeyFromSeed, openEnvelope } from '../support/open';
import { buildJsSealed, serialize } from '../vectors/generate-js';

const generateDirectory = new URL('../vectors/generate/', import.meta.url).pathname;
// scripts/test-web.sh makes the venv at web/.venv; a hand-made one may sit next to the generator.
const venvPythons = [new URL('../../.venv/bin/python', import.meta.url).pathname, join(generateDirectory, '.venv', 'bin', 'python')];

function pythonWithPyhpke(): string | null {
  const candidates = [...venvPythons, 'python3'];
  for (const candidate of candidates) {
    if (candidate !== 'python3' && !existsSync(candidate)) continue;
    try {
      execFileSync(candidate, ['-I', '-c', 'import pyhpke, cryptography'], { stdio: 'ignore' });
      return candidate;
    } catch {
      // try the next one
    }
  }
  return null;
}

const python = pythonWithPyhpke();

function verify(file: string): string {
  if (python === null) throw new Error('no Python with pyhpke');
  return execFileSync(python, [join(generateDirectory, 'verify_js.py'), file], { encoding: 'utf8', cwd: generateDirectory });
}

describe('the browser seals, Python opens', () => {
  it('js-sealed.json is exactly what the page code produces today', async () => {
    const committed = readFileSync(new URL('../vectors/js-sealed.json', import.meta.url), 'utf8');
    expect(serialize(await buildJsSealed())).toBe(committed);
  });

  it.skipIf(python === null)('Python opens the committed js-sealed.json', () => {
    const output = verify(new URL('../vectors/js-sealed.json', import.meta.url).pathname);
    const cases = (JSON.parse(readFileSync(new URL('../vectors/js-sealed.json', import.meta.url), 'utf8')) as { cases: unknown[] }).cases.length;
    expect(cases).toBe(11);
    expect(output).toContain(`${String(cases)}/${String(cases)} envelopes opened`);
  });

  it.skipIf(python === null)('Python opens fresh envelopes sealed with a random key pair and random ephemeral keys', async () => {
    const seed = new Uint8Array(randomBytes(32));
    const key = await inboxKeyFromSeed(seed);
    const submitted = new Date().toISOString();
    const requests = [
      { name: 'random-intake', kind: 'intake' as const, payload: { schema: 1, bookingId: 'bk_x', clientName: 'Zoë Ñandú', answers: { anythingElse: 'sin perfumes — الحساسية 🌿' }, submittedAt: submitted } },
      { name: 'random-checkin', kind: 'checkin' as const, payload: { schema: 1, bookingId: 'bk_x', feeling: 'good', submittedAt: submitted } },
      { name: 'random-request', kind: 'datarequest' as const, payload: { schema: 1, request: 'delete', name: 'Zoë', phone: '+5511999999999', submittedAt: submitted } },
    ];
    const cases = [];
    for (const request of requests) {
      const full = { kind: request.kind, payload: request.payload, inboxKey: key.publicKey };
      const envelope = await sealPayload(full);
      // The plaintext framing is deterministic, so what Python recovers must equal what the page framed.
      cases.push({ name: request.name, recipient: 'k', envelope, plaintext: new TextDecoder().decode(framePlaintext(full)) });
    }
    const directory = join(process.cwd(), 'test-results');
    mkdirSync(directory, { recursive: true });
    const temporary = mkdtempSync(join(directory, 'xt-'));
    try {
      const file = join(temporary, 'random.json');
      writeFileSync(
        file,
        JSON.stringify({ recipients: { k: { privateKey: encodeBase64Url(seed), publicKey: key.publicKey.pub, keyId: key.publicKey.keyId } }, cases }),
      );
      expect(verify(file)).toContain('3/3 envelopes opened');
    } finally {
      rmSync(temporary, { recursive: true, force: true });
    }
  });

  it('two seals of the same payload never repeat (fresh ephemeral key each time)', async () => {
    const key = await inboxKeyFromSeed(new Uint8Array(randomBytes(32)));
    const request = { kind: 'datarequest' as const, payload: { schema: 1, request: 'copy', name: 'A', phone: '+1', submittedAt: 'now' }, inboxKey: key.publicKey, itemId: 'fixed' };
    const a = await sealPayload(request);
    const b = await sealPayload(request);
    expect(a.enc).not.toBe(b.enc);
    expect(a.ct).not.toBe(b.ct);
  });
});

// The other direction (docs/06 section 11 item 5, both ways): envelopes sealed by Apple's CryptoKit, the library the
// iPhone uses (generate/generate-swift.swift), open with the page's suite and with Python. The iPhone's own test
// (BelloHubTests InboxVectorsTests) opens js-sealed.json and reads every payload the page built.
interface SwiftSealedFile {
  recipients: Record<string, { privateKey: string; publicKey: string; keyId: string }>;
  cases: { name: string; recipient: string; kind: string; plaintext: string; envelope: SealedEnvelope }[];
}

describe('CryptoKit seals, the page and Python open', () => {
  const file = JSON.parse(readFileSync(new URL('../vectors/swift-sealed.json', import.meta.url), 'utf8')) as SwiftSealedFile;
  const pageFile = JSON.parse(readFileSync(new URL('../vectors/js-sealed.json', import.meta.url), 'utf8')) as SwiftSealedFile;

  it('covers every plaintext of js-sealed.json', () => {
    expect(file.cases.map((item) => [item.name, item.plaintext])).toEqual(pageFile.cases.map((item) => [item.name, item.plaintext]));
  });

  it('hpke-js opens every CryptoKit envelope to the exact plaintext', async () => {
    for (const item of file.cases) {
      const recipient = file.recipients[item.recipient];
      expect(recipient, item.name).toBeDefined();
      const opened = await openEnvelope(item.envelope, decodeBase64Url(recipient?.privateKey ?? ''));
      expect(opened, item.name).toBe(item.plaintext);
    }
  });

  it('a CryptoKit envelope moved to another item or kind does not open', async () => {
    const item = file.cases[0];
    const recipient = item === undefined ? undefined : file.recipients[item.recipient];
    if (item === undefined || recipient === undefined) throw new Error('empty swift-sealed.json');
    const key = decodeBase64Url(recipient.privateKey);
    await expect(openEnvelope({ ...item.envelope, itemId: 'another-item' }, key)).rejects.toThrow();
    await expect(openEnvelope({ ...item.envelope, kind: item.envelope.kind === 'intake' ? 'checkin' : 'intake' }, key)).rejects.toThrow();
  });

  it.skipIf(python === null)('Python opens the CryptoKit envelopes', () => {
    const output = verify(new URL('../vectors/swift-sealed.json', import.meta.url).pathname);
    expect(output).toContain(`${String(file.cases.length)}/${String(file.cases.length)} envelopes opened`);
  });
});
