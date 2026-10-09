// The privacy gate of the web app (docs/10-WEB-BOOKING.md section 10, docs/06-PRIVACY-SECURITY.md section 6).
// It reads the TypeScript syntax tree, so a comment that talks about localStorage is not a violation and a real
// use is, whatever the formatting.
//
//   npx tsx scripts/check-privacy.ts
//
// Rules:
//   1. The sealed-form routes (form, checkin, data) and the crypto folder never touch browser storage or cookies.
//   2. Nothing in src writes markup from a string (innerHTML, dangerouslySetInnerHTML, document.write, eval,
//      new Function) and nothing calls console.* (a logged answer would be a leak).
//   3. The only absolute URLs in the source are the two links the page opens on the client's request.
//   4. index.html loads nothing from another origin and has no inline script.
//   5. D46: no Firebase SDK in the browser (no import, no dependency) and the CSP names no other origin.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const src = join(root, 'src');
const problems: string[] = [];

function walk(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return walk(path);
    return /\.(ts|tsx)$/.test(name) && !name.endsWith('.generated.ts') ? [path] : [];
  });
}

const FIREBASE = /^(@firebase\/|firebase(\/|$))/;
const STORAGE = new Set(['localStorage', 'sessionStorage', 'indexedDB', 'cookie', 'caches', 'openDatabase']);
const MARKUP = new Set(['innerHTML', 'outerHTML', 'insertAdjacentHTML', 'dangerouslySetInnerHTML', 'eval']);
// The two links the page opens because the client tapped something: WhatsApp and the calendar.
const ALLOWED_URL = /^https:\/\/(wa\.me\/|calendar\.google\.com\/calendar\/render)/;

function isSealed(file: string): boolean {
  const rel = relative(src, file);
  return /^(routes\/(form|checkin|data)|crypto)\//.test(rel);
}

function report(file: string, node: ts.Node, message: string): void {
  const source = node.getSourceFile();
  const { line } = source.getLineAndCharacterOfPosition(node.getStart());
  problems.push(`${relative(root, file)}:${line + 1}: ${message}`);
}

for (const file of walk(src)) {
  const source = ts.createSourceFile(file, readFileSync(file, 'utf8'), ts.ScriptTarget.ES2022, true, file.endsWith('x') ? ts.ScriptKind.TSX : ts.ScriptKind.TS);
  const sealed = isSealed(file);
  const visit = (node: ts.Node): void => {
    if (ts.isIdentifier(node)) {
      if (sealed && STORAGE.has(node.text)) report(file, node, `sealed code touches ${node.text}`);
      if (MARKUP.has(node.text)) report(file, node, `${node.text} writes markup from a string`);
      if (node.text === 'console') report(file, node, 'console is never used: a logged value can be a leak');
    }
    if (ts.isImportDeclaration(node) && ts.isStringLiteral(node.moduleSpecifier) && FIREBASE.test(node.moduleSpecifier.text)) {
      report(file, node, 'the page ships no Firebase SDK (D46)');
    }
    if (ts.isCallExpression(node) && node.expression.kind === ts.SyntaxKind.ImportKeyword) {
      const [argument] = node.arguments;
      if (argument !== undefined && ts.isStringLiteral(argument) && FIREBASE.test(argument.text)) report(file, node, 'the page ships no Firebase SDK (D46)');
    }
    if (ts.isNewExpression(node) && ts.isIdentifier(node.expression) && node.expression.text === 'Function') report(file, node, 'new Function builds code from a string');
    if (ts.isPropertyAccessExpression(node) && ts.isIdentifier(node.expression) && node.expression.text === 'document' && node.name.text === 'write') {
      report(file, node, 'document.write writes markup from a string');
    }
    if ((ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node) || ts.isTemplateHead(node)) && /^https?:\/\//.test(node.text)) {
      if (!ALLOWED_URL.test(node.text) && node.text !== 'http://www.w3.org/2000/svg') report(file, node, `absolute URL ${node.text.slice(0, 40)} is not on the allowlist`);
    }
    ts.forEachChild(node, visit);
  };
  visit(source);
}

// MARK: index.html

const html = readFileSync(join(root, 'index.html'), 'utf8');
for (const match of html.matchAll(/<(script|link|img|iframe|object|embed|form)\b[^>]*>/gi)) {
  const tag = match[0];
  if (/(?:src|href|action)\s*=\s*["']?(?:https?:)?\/\//i.test(tag)) problems.push(`index.html: ${tag.slice(0, 60)} points at another origin`);
  if (/^<script\b/i.test(tag) && !/\bsrc\s*=/.test(tag)) problems.push('index.html: inline script (the CSP allows script-src self only)');
}
if (/<style\b/i.test(html)) problems.push('index.html: inline <style> (the CSP allows style-src self only)');
if (/\son[a-z]+\s*=/i.test(html)) problems.push('index.html: inline event handler');

const manifest = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')) as { dependencies?: Record<string, string> };
for (const name of Object.keys(manifest.dependencies ?? {})) {
  if (FIREBASE.test(name)) problems.push(`package.json: dependency ${name} (D46: no Firebase SDK in the browser)`);
}
const hosting = readFileSync(join(root, 'hosting.json'), 'utf8');
const csp = /"Content-Security-Policy",\s*"value":\s*"([^"]*)"/.exec(hosting)?.[1] ?? '';
if (csp === '') problems.push('hosting.json: no Content-Security-Policy found');
if (/https?:\/\/|\*\./.test(csp)) problems.push('hosting.json: the CSP names another origin');
if (!csp.includes("connect-src 'self';")) problems.push("hosting.json: connect-src must be 'self' only");

if (problems.length > 0) {
  for (const problem of problems) process.stderr.write(`FAIL ${problem}\n`);
  process.stderr.write(`privacy: ${problems.length} problem${problems.length === 1 ? '' : 's'}\n`);
  process.exit(1);
}
process.stdout.write('privacy: sealed routes touch no storage, no console, no string markup, no stray URLs\n');
