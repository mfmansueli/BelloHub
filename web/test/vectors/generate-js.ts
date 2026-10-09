// Writes web/test/vectors/js-sealed.json: envelopes sealed by the page's own code (hpke-js), with fixed ephemeral
// key material so the file is reproducible. Python (`generate/verify_js.py`) opens them, and so will Swift later.
//
//   npx tsx test/vectors/generate-js.ts          writes the file
//   npx tsx test/vectors/generate-js.ts --check  fails when the committed file is stale

import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

import { encodeBase64Url } from '../../src/lib/base64url';
import { framePlaintext, sealPayload } from '../../src/crypto/seal';
import type { InboxKey, SealedEnvelope } from '../../src/api/types';

interface Recipient {
  privateKey: string;
  publicKey: string;
  keyId: string;
}

interface SourceCase {
  name: string;
  kind: 'intake' | 'checkin' | 'datarequest';
  hasPhoto: boolean;
  payload: object;
}

const here = new URL('.', import.meta.url);
const source = JSON.parse(readFileSync(new URL('inbox-v1.json', here), 'utf8')) as {
  recipients: Record<string, Recipient>;
  positive: SourceCase[];
};

function fixed(label: string): Uint8Array {
  return new Uint8Array(createHash('sha256').update(label).digest());
}

function itemIdFor(name: string): string {
  const raw = fixed(`bellohub/vectors/js-item/${name}`).slice(0, 16);
  raw[6] = ((raw[6] ?? 0) & 0x0f) | 0x40;
  raw[8] = ((raw[8] ?? 0) & 0x3f) | 0x80;
  const hex = Buffer.from(raw).toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export interface JsSealedFile {
  schema: 1;
  description: string;
  generator: string;
  recipients: Record<string, Recipient>;
  cases: { name: string; recipient: string; kind: string; hasPhoto: boolean; itemId: string; ikmE: string; payload: object; plaintext: string; envelope: SealedEnvelope }[];
}

export async function buildJsSealed(): Promise<JsSealedFile> {
  const recipientId = 'r2';
  const recipient = source.recipients[recipientId];
  if (recipient === undefined) throw new Error('recipient r2 missing from inbox-v1.json');
  const inboxKey: InboxKey = { keyId: recipient.keyId, alg: 'hpke-v1', pub: recipient.publicKey };
  const cases: JsSealedFile['cases'] = [];
  for (const item of source.positive) {
    const itemId = itemIdFor(item.name);
    const ikm = fixed(`bellohub/vectors/js-ikmE/${item.name}`);
    const request = { kind: item.kind, payload: item.payload, inboxKey, hasPhoto: item.hasPhoto, itemId };
    const envelope = await sealPayload(request, { ephemeralIkm: ikm });
    cases.push({
      name: item.name,
      recipient: recipientId,
      kind: item.kind,
      hasPhoto: item.hasPhoto,
      itemId,
      ikmE: encodeBase64Url(ikm),
      payload: item.payload,
      plaintext: new TextDecoder().decode(framePlaintext(request)),
      envelope,
    });
  }
  return {
    schema: 1,
    description:
      'Envelopes sealed by the page itself (hpke-js through src/crypto/seal.ts) with fixed ephemeral key material. ' +
      'Opening each `envelope` with the private key of `recipient` (inbox-v1.json) must give exactly `plaintext`. ' +
      'Python opens them in test/vectors/generate/verify_js.py; Swift should open them too.',
    generator: 'web/test/vectors/generate-js.ts',
    recipients: { [recipientId]: recipient },
    cases,
  };
}

export function serialize(file: JsSealedFile): string {
  return `${JSON.stringify(file, null, 2)}\n`;
}

if (process.argv[1] !== undefined && process.argv[1].endsWith('generate-js.ts')) {
  const text = serialize(await buildJsSealed());
  const target = new URL('js-sealed.json', here);
  if (process.argv.includes('--check')) {
    let current = '';
    try {
      current = readFileSync(target, 'utf8');
    } catch {
      current = '';
    }
    if (current !== text) {
      process.stderr.write('error: js-sealed.json is stale; run: npx tsx test/vectors/generate-js.ts\n');
      process.exit(1);
    }
  } else {
    writeFileSync(target, text);
    process.stdout.write(`wrote js-sealed.json (${text.length} bytes)\n`);
  }
}
