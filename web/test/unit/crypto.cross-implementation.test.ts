// "Someone else's decryption" (docs/06 section 11 item 5): what the browser's code seals is opened by Python
// (pyhpke + cryptography), a different implementation, in a separate process.

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

import { encodeBase64Url } from '../../src/lib/base64url';
import { framePlaintext, sealPayload } from '../../src/crypto/seal';
import { inboxKeyFromSeed } from '../support/open';
import { buildJsSealed, serialize } from '../vectors/generate-js';

const generateDirectory = new URL('../vectors/generate/', import.meta.url).pathname;
const venvPython = join(generateDirectory, '.venv', 'bin', 'python');

function pythonWithPyhpke(): string | null {
  const candidates = [venvPython, 'python3'];
  for (const candidate of candidates) {
    if (candidate === venvPython && !existsSync(candidate)) continue;
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
    expect(output).toContain('9/9 envelopes opened');
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
