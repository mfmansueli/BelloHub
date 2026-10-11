// The size budget of docs/10 section 1, measured on the production build in dist/:
//   initial JavaScript   <= 80 KB gzip   (what index.html loads before the first screen)
//   CSS                  <= 15 KB gzip
//   the sealing chunk    <= 60 KB gzip   (hpke-js, loaded only when a sealed form is submitted)
//   each language file   <= 15 KB gzip   (loaded on demand)
// Exits 1 when any is over. Run after `vite build` (npm run build does).

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gzipSync } from 'node:zlib';

const dist = resolve(dirname(fileURLToPath(import.meta.url)), '../dist');
const KB = 1024;

function walk(directory: string): string[] {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

const gz = (file: string): number => gzipSync(readFileSync(file), { level: 9 }).length;
const html = readFileSync(join(dist, 'index.html'), 'utf8');
const referenced = new Set([...html.matchAll(/(?:src|href)="\/(assets\/[^"]+)"/g)].map((match) => match[1] ?? ''));

const files = walk(dist).filter((file) => /\.(js|css)$/.test(file));
let initialJs = 0;
let css = 0;
const lazy: { name: string; bytes: number; text: string }[] = [];
for (const file of files) {
  const name = relative(dist, file);
  const bytes = gz(file);
  if (file.endsWith('.css')) css += bytes;
  else if (referenced.has(name)) initialJs += bytes;
  else lazy.push({ name, bytes, text: readFileSync(file, 'utf8') });
}

const problems: string[] = [];
const rows: string[] = [];
const check = (label: string, bytes: number, budget: number): void => {
  const mark = bytes <= budget * KB ? 'ok  ' : 'FAIL';
  rows.push(`${mark} ${label.padEnd(34)} ${(bytes / KB).toFixed(1).padStart(6)} KB gzip  (budget ${budget} KB)`);
  if (bytes > budget * KB) problems.push(`${label}: ${(bytes / KB).toFixed(1)} KB gzip is over ${budget} KB`);
};

check('initial JavaScript', initialJs, 80);
check('CSS', css, 15);
for (const chunk of lazy.sort((a, b) => b.bytes - a.bytes)) {
  if (chunk.text.includes('bellohub/inbox/v1')) check(`sealing chunk (${chunk.name})`, chunk.bytes, 60);
  else if (/hpke|HKDF/i.test(chunk.text) && chunk.text.length > 20_000) check(`crypto library (${chunk.name})`, chunk.bytes, 60);
  else if (/^assets\/(pt-BR|pt-PT|es-MX|es-419|es|en|en-GB|it|fr|de|tr|id|hi|ar)-/.test(chunk.name)) check(`language or legal text (${chunk.name})`, chunk.bytes, 15);
  else rows.push(`     ${`lazy ${chunk.name}`.padEnd(34)} ${(chunk.bytes / KB).toFixed(1).padStart(6)} KB gzip`);
}

process.stdout.write(`${rows.join('\n')}\n`);
if (problems.length > 0) {
  for (const problem of problems) process.stderr.write(`FAIL ${problem}\n`);
  process.exit(1);
}
process.stdout.write('size budget: ok\n');
