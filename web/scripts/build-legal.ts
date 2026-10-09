// Embeds the client-facing legal texts (legal/<document>/<localization>/<version>.md) into the page, once per
// document and localization, as a small block tree the page renders without a markdown library and without
// innerHTML. The texts are not edited here (legal/ is the source); only placeholders are filled:
//
//   {{WEB_BASE_URL}}, {{OPERATOR_NAME}}, {{OPERATOR_EMAIL}}, {{OPERATOR_ADDRESS}}, {{EFFECTIVE_DATE}}
//       filled at build time from the environment (BELLO_WEB_BASE_URL, BELLO_OPERATOR_NAME, BELLO_OPERATOR_EMAIL,
//       BELLO_OPERATOR_ADDRESS) or Config/Legal/operator.json when it exists. A missing operator value stays visible
//       as [OPERATOR_...] and the build says so; BELLO_STRICT_LEGAL=1 makes it fail (release builds).
//   {{PROFESSIONAL_NAME}}
//       kept as a node of its own: only the page knows it, from the professional's public profile.
//
// Output (git-ignored): src/legal/generated/<document>/<localization>.json

import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const legalRoot = resolve(here, '../../legal');
const outRoot = resolve(here, '../src/legal/generated');

/** The documents the web shows (privacy policy for the /privacy page, the rest inside the flows). D49: the consent texts are not here: the
 * consent a client signs is the one the server serves for that professional. */
export const DOCUMENTS = ['client-notice', 'data-requests', 'privacy-policy'] as const;
export type LegalDocument = (typeof DOCUMENTS)[number];

export const LOCALIZATIONS = ['pt-BR', 'pt-PT', 'es-MX', 'es-419', 'es', 'en', 'en-GB', 'it', 'fr', 'de', 'tr', 'id', 'hi', 'ar'] as const;

export type Inline = { k: 't'; v: string } | { k: 'b'; v: string } | { k: 'a'; v: string } | { k: 'pro' };

export type Block =
  | { type: 'h1'; text: Inline[] }
  | { type: 'p'; text: Inline[] }
  | { type: 'ul'; items: Inline[][] }
  | { type: 'check'; text: Inline[] }
  | { type: 'consent'; heading: Inline[]; statement: Inline[]; signLabel: string };

export interface LegalFile {
  version: string;
  blocks: Block[];
}

interface Operator {
  name: string;
  email: string;
  address: string;
}

function operator(): { values: Operator; missing: string[] } {
  let file: Partial<Operator> = {};
  const path = resolve(here, '../../Config/Legal/operator.json');
  if (existsSync(path)) {
    try {
      file = JSON.parse(readFileSync(path, 'utf8')) as Partial<Operator>;
    } catch {
      file = {};
    }
  }
  const missing: string[] = [];
  const pick = (value: string | undefined, fromFile: string | undefined, label: string): string => {
    const found = value ?? fromFile;
    if (found === undefined || found === '') {
      missing.push(label);
      return `[${label}]`;
    }
    return found;
  };
  return {
    values: {
      name: pick(process.env['BELLO_OPERATOR_NAME'], file.name, 'OPERATOR_NAME'),
      email: pick(process.env['BELLO_OPERATOR_EMAIL'], file.email, 'OPERATOR_EMAIL'),
      address: pick(process.env['BELLO_OPERATOR_ADDRESS'], file.address, 'OPERATOR_ADDRESS'),
    },
    missing,
  };
}

function effectiveDate(version: string, localization: string): string {
  const [year, month] = version.split('-').map(Number);
  if (year === undefined || month === undefined) return version;
  return new Intl.DateTimeFormat(localization, { month: 'long', year: 'numeric', timeZone: 'UTC' }).format(Date.UTC(year, month - 1, 1));
}

function inlines(text: string): Inline[] {
  const out: Inline[] = [];
  const pattern = /(\*\*[^*]+\*\*)|(\{\{PROFESSIONAL_NAME\}\})|(https?:\/\/[^\s)]+[^\s).,;:])/g;
  let last = 0;
  for (const match of text.matchAll(pattern)) {
    const index = match.index;
    if (index > last) out.push({ k: 't', v: text.slice(last, index) });
    if (match[1] !== undefined) out.push({ k: 'b', v: match[1].slice(2, -2) });
    else if (match[2] !== undefined) out.push({ k: 'pro' });
    else if (match[3] !== undefined) out.push({ k: 'a', v: match[3] });
    last = index + match[0].length;
  }
  if (last < text.length) out.push({ k: 't', v: text.slice(last) });
  return out;
}

function parse(markdown: string, fill: (text: string) => string): LegalFile {
  const match = markdown.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (match === null) throw new Error('missing front matter');
  const version = /^version:\s*(\S+)/m.exec(match[1] ?? '')?.[1] ?? '';
  const blocks: Block[] = [];
  let list: Inline[][] | null = null;
  for (const raw of (match[2] ?? '').split('\n')) {
    const line = fill(raw.trimEnd());
    if (line === '') {
      list = null;
      continue;
    }
    if (line.startsWith('# ')) {
      list = null;
      blocks.push({ type: 'h1', text: inlines(line.slice(2)) });
    } else if (line.startsWith('- ')) {
      if (list === null) {
        list = [];
        blocks.push({ type: 'ul', items: list });
      }
      list.push(inlines(line.slice(2)));
    } else if (line.startsWith('☐')) {
      list = null;
      blocks.push({ type: 'check', text: inlines(line.slice(1).trim()) });
    } else {
      list = null;
      const consent = /^\*\*(.+?)\*\*\s*☐\s*(.+)$/.exec(line);
      if (consent !== null) {
        const rest = consent[2] ?? '';
        // The statement ends at the last sentence end; what follows is the label of the signature field.
        let cut = -1;
        for (const boundary of rest.matchAll(/[.。।]\s/g)) cut = boundary.index + 1;
        if (cut < 0) throw new Error('consent paragraph without a signature label');
        blocks.push({
          type: 'consent',
          heading: inlines(consent[1] ?? ''),
          statement: inlines(rest.slice(0, cut).trim()),
          signLabel: rest.slice(cut).trim().replace(/\s*[:：]$/, ''),
        });
      } else {
        blocks.push({ type: 'p', text: inlines(line) });
      }
    }
  }
  return { version, blocks };
}

function main(): void {
  const { values, missing } = operator();
  const baseUrl = (process.env['BELLO_WEB_BASE_URL'] ?? 'https://bellohub.app').replace(/\/+$/, '');
  rmSync(outRoot, { recursive: true, force: true });
  let files = 0;
  for (const document of DOCUMENTS) {
    for (const localization of LOCALIZATIONS) {
      const directory = join(legalRoot, document, localization);
      const versions = readdirSync(directory).filter((name) => name.endsWith('.md')).sort();
      const latest = versions.at(-1);
      if (latest === undefined) throw new Error(`no version for ${document}/${localization}`);
      const version = latest.replace(/\.md$/, '');
      const fill = (text: string): string =>
        text
          .replaceAll('{{WEB_BASE_URL}}', baseUrl)
          .replaceAll('{{OPERATOR_NAME}}', values.name)
          .replaceAll('{{OPERATOR_EMAIL}}', values.email)
          .replaceAll('{{OPERATOR_ADDRESS}}', values.address)
          .replaceAll('{{EFFECTIVE_DATE}}', effectiveDate(version, localization));
      const parsed = parse(readFileSync(join(directory, latest), 'utf8'), fill);
      const unresolved = JSON.stringify(parsed).match(/\{\{[A-Z_]+\}\}/);
      if (unresolved !== null) throw new Error(`${document}/${localization}: unresolved ${unresolved[0]}`);
      mkdirSync(join(outRoot, document), { recursive: true });
      writeFileSync(join(outRoot, document, `${localization}.json`), JSON.stringify(parsed));
      files += 1;
    }
  }
  const note = missing.length === 0 ? '' : ` (operator values missing: ${missing.join(', ')}; the privacy policy shows them in brackets)`;
  process.stdout.write(`legal: ${files} files embedded${note}\n`);
  if (missing.length > 0 && process.env['BELLO_STRICT_LEGAL'] === '1') {
    process.stderr.write('error: BELLO_STRICT_LEGAL=1 and operator details are missing\n');
    process.exit(1);
  }
}

main();
