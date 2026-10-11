// Finds the message keys the source code uses and the parameters each call site passes, so the i18n check can say
// "a key in the code is missing from the catalog", "a key in the catalog is unused" and "this call does not pass a
// placeholder the message needs". It reads the TypeScript syntax tree, so strings in comments never count.

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import ts from 'typescript';

export interface KeyUse {
  readonly key: string;
  readonly file: string;
  /** Parameters passed in a `t(key, { ... })` call; null when the key is only mentioned (a table of keys). */
  readonly params: ReadonlySet<string> | null;
}

/** The first segment of every key. A literal that looks like `ns.word` with another prefix is not a key. */
export const NAMESPACES = [
  'common', 'lang', 'err', 'state', 'landing', 'price', 'cal', 'wait', 'wa', 'ics', 'legal', 'loc',
  'br', 'bk1', 'bk2', 'bk4', 'bk5', 'bk6', 'bk7', 'bk8', 'bk9', 'bk10', 'bk11',
  'cl2', 'cl3', 'cl4', 'cl5', 'cl6', 'cl7', 'cl9',
] as const;

const KEY = new RegExp(`^(?:${NAMESPACES.join('|')})(?:\\.[A-Za-z0-9]+)+$`);

function walk(directory: string): string[] {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    if (statSync(path).isDirectory()) return entry === 'generated' ? [] : walk(path);
    return /\.(ts|tsx)$/.test(path) ? [path] : [];
  });
}

function propertyNames(object: ts.ObjectLiteralExpression): Set<string> {
  const names = new Set<string>();
  for (const property of object.properties) {
    if ((ts.isPropertyAssignment(property) || ts.isShorthandPropertyAssignment(property)) && ts.isIdentifier(property.name)) {
      names.add(property.name.text);
    } else if ((ts.isPropertyAssignment(property)) && ts.isStringLiteral(property.name)) {
      names.add(property.name.text);
    }
  }
  return names;
}

export function findKeyUses(root: string): KeyUse[] {
  const uses: KeyUse[] = [];
  for (const file of walk(root)) {
    const source = ts.createSourceFile(file, readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true, file.endsWith('x') ? ts.ScriptKind.TSX : ts.ScriptKind.TS);
    const counted = new Set<ts.Node>();
    const visit = (node: ts.Node): void => {
      if (ts.isCallExpression(node) && ts.isIdentifier(node.expression) && node.expression.text === 't') {
        const [first, second] = node.arguments;
        if (first !== undefined && (ts.isStringLiteral(first) || ts.isNoSubstitutionTemplateLiteral(first)) && KEY.test(first.text)) {
          counted.add(first);
          uses.push({ key: first.text, file, params: second !== undefined && ts.isObjectLiteralExpression(second) ? propertyNames(second) : new Set() });
        }
      } else if ((ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) && !counted.has(node) && KEY.test(node.text)) {
        uses.push({ key: node.text, file, params: null });
      }
      ts.forEachChild(node, visit);
    };
    visit(source);
  }
  return uses;
}
