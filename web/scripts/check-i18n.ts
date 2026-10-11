// The localization gate (docs/07 section 9, the web part): every key in every one of the fourteen localizations,
// no empty value, the same placeholders, every plural category the language needs (six for Arabic), keys the code
// uses and the catalog lacks (and the other way round), call sites that forget a placeholder, and the vocabulary and
// address rules per language (docs/07 section 1 and 4). It also prints the coverage table with the review state.
//
//   npx tsx scripts/check-i18n.ts          exits 1 on any problem, prints the table
//   npx tsx scripts/check-i18n.ts --quiet  prints only problems and one summary line

import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { findKeyUses } from './lib/i18n-keys';

const here = dirname(fileURLToPath(import.meta.url));
const i18n = resolve(here, '../src/i18n');
const LOCALES = ['pt-BR', 'pt-PT', 'es-MX', 'es-419', 'es', 'en', 'en-GB', 'it', 'fr', 'de', 'tr', 'id', 'hi', 'ar'] as const;
const AUTHORED = LOCALES.filter((id) => id !== 'es-419' && id !== 'en-GB');

type Message = string | Record<string, string>;
type Catalog = Record<string, Message>;

const problems: string[] = [];
const fail = (locale: string, text: string): void => {
  problems.push(`${locale}: ${text}`);
};

function load(locale: string): Catalog | null {
  const path = resolve(i18n, `${locale}.json`);
  if (!existsSync(path)) {
    fail(locale, 'file is missing');
    return null;
  }
  try {
    return JSON.parse(readFileSync(path, 'utf8')) as Catalog;
  } catch {
    fail(locale, 'not valid JSON');
    return null;
  }
}

function placeholders(text: string): string[] {
  return [...new Set([...text.matchAll(/\{(\w+)\}/g)].map((match) => match[1] ?? ''))].sort();
}

/** The plural categories a language must provide. `many` is only for large numbers in es, fr, it and pt: the page never reaches it. */
function categories(locale: string): string[] {
  const language = locale.split('-')[0] ?? locale;
  const all = new Intl.PluralRules(locale).resolvedOptions().pluralCategories;
  return all.filter((category) => !(category === 'many' && ['es', 'fr', 'it', 'pt'].includes(language))).sort();
}

const catalogs = new Map<string, Catalog>();
for (const locale of LOCALES) {
  const catalog = load(locale);
  if (catalog !== null) catalogs.set(locale, catalog);
}
const source = catalogs.get('en');
if (source === undefined) {
  process.stderr.write('error: en.json (the source catalog) is missing\n');
  process.exit(1);
}

// MARK: Structure of every catalog against the source

for (const [locale, catalog] of catalogs) {
  for (const key of Object.keys(source)) {
    const original = source[key];
    const value = catalog[key];
    if (original === undefined) continue;
    if (value === undefined) {
      fail(locale, `missing key ${key}`);
      continue;
    }
    const sourceIsPlural = typeof original !== 'string';
    if (typeof value === 'string') {
      if (sourceIsPlural) fail(locale, `${key} must have plural forms`);
      if (value.trim() === '') fail(locale, `${key} is empty`);
      else {
        if (value !== value.trim()) fail(locale, `${key} has leading or trailing space`);
        if (/[<>]/.test(value)) fail(locale, `${key} contains markup characters`);
      }
      if (!sourceIsPlural) {
        const want = placeholders(original);
        const got = placeholders(value);
        if (want.join() !== got.join()) fail(locale, `${key} placeholders {${got.join(',')}} differ from the source {${want.join(',')}}`);
      }
      continue;
    }
    if (!sourceIsPlural) {
      fail(locale, `${key} must be a plain string`);
      continue;
    }
    const required = categories(locale);
    const present = Object.keys(value).sort();
    for (const category of required) if (!present.includes(category)) fail(locale, `${key} lacks the plural form "${category}"`);
    for (const category of present) if (!required.includes(category) && !(category === 'many')) fail(locale, `${key} has the unused plural form "${category}"`);
    const sourceOther = (original)['other'] ?? '';
    const want = placeholders(sourceOther);
    for (const category of present) {
      const text = value[category] ?? '';
      if (text.trim() === '') fail(locale, `${key}.${category} is empty`);
      if (/[<>]/.test(text)) fail(locale, `${key}.${category} contains markup characters`);
      const got = placeholders(text);
      // A singular form may leave the number out ("one guest"); every other placeholder must stay.
      const needed = category === 'other' ? want : want.filter((name) => name !== 'count');
      for (const name of needed) if (!got.includes(name)) fail(locale, `${key}.${category} lacks {${name}}`);
      for (const name of got) if (!want.includes(name)) fail(locale, `${key}.${category} has {${name}}, which the source does not use`);
    }
  }
  for (const key of Object.keys(catalog)) if (!(key in source)) fail(locale, `extra key ${key}`);
}

// MARK: The code against the catalog

const uses = findKeyUses(resolve(here, '../src'));
const used = new Set(uses.map((use) => use.key));
for (const key of used) if (!(key in source)) problems.push(`code: uses ${key}, which the catalog does not have`);
for (const key of Object.keys(source)) if (!used.has(key)) problems.push(`en: ${key} is not used by the code`);
for (const use of uses) {
  if (use.params === null) continue;
  const message = source[use.key];
  if (message === undefined) continue;
  const text = typeof message === 'string' ? message : Object.values(message).join(' ');
  for (const name of placeholders(text)) {
    if (!use.params.has(name)) problems.push(`code: ${use.file.split('/src/')[1] ?? use.file} calls t('${use.key}') without {${name}}`);
  }
}

// MARK: Voice and vocabulary per language (docs/07 section 1 and 4)

const GUARDS: Readonly<Record<string, readonly { pattern: RegExp; why: string }[]>> = {
  'pt-PT': [
    { pattern: /\bvocê(s)?\b/i, why: 'pt-PT avoids "você"' },
    { pattern: /\bagendamento\b|\bagendar\b/i, why: 'pt-PT says "marcação"/"marcar"' },
    { pattern: /\bcelular\b/i, why: 'pt-PT says "telemóvel"' },
  ],
  'pt-BR': [
    { pattern: /\bmarcação\b|\bmarcar\b/i, why: 'pt-BR says "agendamento"/"agendar"' },
    { pattern: /\btelemóvel\b|\bdesmarcar\b/i, why: 'pt-BR says "celular"/"cancelar"' },
  ],
  es: [{ pattern: /\bcelular\b|\busted(es)?\b/i, why: 'Spain says "móvil" and uses tú' }],
  'es-MX': [{ pattern: /\bmóvil\b|\busted(es)?\b|\bvos\b/i, why: 'Mexico says "celular" and uses tú' }],
  'es-419': [{ pattern: /\bvos\b|\busted(es)?\b/i, why: 'es-419 uses tú, no voseo' }],
  de: [
    { pattern: /Kund:in|Kund\*in|Kund_in|Kunden\/innen|Kundinnen und Kunden|Kund\/in/, why: 'German uses "Kundschaft", no gender marks' },
    { pattern: /\b(du|dein|deine|deinen|deinem|deiner|deines|dich|dir)\b/, why: 'client pages address with "Sie"' },
  ],
  // Unicode-aware boundaries: a plain \b treats "ê" as a non-letter and would flag "êtes" as "tes".
  fr: [{ pattern: /(?<![\p{L}'])(tu|ton|ta|tes|toi|te)(?![\p{L}])/iu, why: 'French uses "vous" everywhere' }],
  id: [{ pattern: /\b(kamu|kau|engkau)\b/i, why: 'client pages say "Anda"' }],
  hi: [{ pattern: /तुम|तू |तेरा|तुम्हारा/, why: 'Hindi uses the polite "आप"' }],
  tr: [{ pattern: /\bsen\b|\bsana\b|\bsenin\b/i, why: 'Turkish uses the polite "siz"' }],
};

for (const [locale, catalog] of catalogs) {
  for (const guard of GUARDS[locale] ?? []) {
    for (const [key, value] of Object.entries(catalog)) {
      const texts = typeof value === 'string' ? [value] : Object.values(value);
      for (const text of texts) {
        const stripped = text.replace(/\{\w+\}/g, '');
        if (guard.pattern.test(stripped)) fail(locale, `${key}: ${guard.why} ("${stripped.slice(0, 60)}")`);
      }
    }
  }
}

// MARK: Review manifest (every string is needs_review: no native has read it, D41)

interface Manifest {
  readonly locales: Record<string, { readonly state: string; readonly reviewedKeys?: readonly string[] }>;
}
const manifestPath = resolve(i18n, 'manifest.json');
let manifest: Manifest | null = null;
if (existsSync(manifestPath)) manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as Manifest;
else problems.push('manifest.json is missing');
for (const locale of LOCALES) {
  const entry = manifest?.locales[locale];
  if (entry === undefined) problems.push(`manifest.json has no entry for ${locale}`);
  else if (!['needs_review', 'translated'].includes(entry.state)) problems.push(`manifest.json: ${locale} has the unknown state ${entry.state}`);
}

const quiet = process.argv.includes('--quiet');
if (!quiet) {
  process.stdout.write('\nlocale   keys  filled  reviewed  state\n');
  for (const locale of LOCALES) {
    const catalog = catalogs.get(locale);
    const keys = catalog === undefined ? 0 : Object.keys(catalog).length;
    const entry = manifest?.locales[locale];
    const reviewed = entry?.reviewedKeys?.length ?? 0;
    const filled = Object.keys(source).filter((key) => catalog?.[key] !== undefined).length;
    const derived = locale === 'es-419' || locale === 'en-GB' ? ' (derived)' : AUTHORED.includes(locale) ? '' : '';
    process.stdout.write(`${locale.padEnd(8)} ${String(keys).padStart(4)}  ${String(Math.round((filled / Object.keys(source).length) * 100)).padStart(5)}%  ${String(Math.round((reviewed / Object.keys(source).length) * 100)).padStart(7)}%  ${entry?.state ?? '?'}${derived}\n`);
  }
}
for (const problem of problems) process.stderr.write(`FAIL ${problem}\n`);
process.stdout.write(`i18n: ${LOCALES.length} localizations, ${Object.keys(source).length} keys, ${problems.length} problems\n`);
process.exit(problems.length > 0 ? 1 : 0);
