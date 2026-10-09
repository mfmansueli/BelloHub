// Generates src/styles/tokens.generated.css from the iOS design tokens, so the app and the web share one source
// (docs/10-WEB-BOOKING.md section 7: "generated into CSS variables by a script that reads the DS token file").
//
// It reads BelloHub/DesignSystem/Tokens/{Palette,HeroPalette,AvatarPalette,Spacing,Radius,Elevation,Typography,
// Motion}.swift, so a change to a color in Swift changes the page on the next build, and the contrast check
// (scripts/check-contrast.ts) reads the same files. The output is git-ignored and rebuilt by `npm run gen`.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { kebab, parseAliases, parseAvatar, parseColors, parseNumbers, readToken, type ColorToken } from './lib/swift-tokens';

const target = resolve(dirname(fileURLToPath(import.meta.url)), '../src/styles/tokens.generated.css');

const rem = (px: number): string => `${Number((px / 16).toFixed(4))}rem`;
const line = (name: string, value: string): string => `  --${name}: ${value};`;

interface Appearance {
  readonly light: string[];
  readonly dark: string[];
  readonly lightMore: string[];
  readonly darkMore: string[];
}

function addColor(into: Appearance, name: string, color: ColorToken): void {
  into.light.push(line(name, color.light));
  if (color.dark !== color.light) into.dark.push(line(name, color.dark));
  if (color.lightIncreased !== color.light) into.lightMore.push(line(name, color.lightIncreased));
  if (color.darkIncreased !== color.dark) into.darkMore.push(line(name, color.darkIncreased));
}

function colors(): Appearance {
  const appearance: Appearance = { light: [], dark: [], lightMore: [], darkMore: [] };
  const palette = readToken('Palette.swift');
  const tokens = parseColors(palette);
  for (const color of tokens) addColor(appearance, kebab(color.name), color);
  for (const [alias, original] of parseAliases(palette)) {
    if (tokens.some((c) => c.name === original)) appearance.light.push(line(kebab(alias), `var(--${kebab(original)})`));
  }
  const avatar = parseAvatar(readToken('AvatarPalette.swift'));
  for (const part of ['start', 'end', 'text'] as const) {
    for (const [kind, color] of Object.entries(avatar[part])) addColor(appearance, `avatar-${kind}-${part}`, color);
  }
  return appearance;
}

function hero(): string[] {
  const source = readToken('HeroPalette.swift');
  const out = parseColors(source).map((c) => line(`hero-${kebab(c.name)}`, c.light));
  for (const match of source.matchAll(/static let (glowRoseOpacity|glowSageOpacity) = ([\d.]+)/g)) {
    out.push(line(`hero-${kebab(match[1] ?? '')}`, match[2] ?? ''));
  }
  return out;
}

/** Elevation layers: CSS blur is twice the SwiftUI radius and the spread is minus the radius (docs/08 section 4). */
function shadows(): string[] {
  const source = readToken('Elevation.swift');
  const tint = source.match(/static let tint = Color\(hex: (0x[0-9A-Fa-f]+)\)/)?.[1] ?? '0x462D1E';
  const rgb = (tint.replace(/^0x/i, '').match(/../g) ?? []).map((p) => parseInt(p, 16)).join(',');
  const out: string[] = [];
  const layer = String.raw`Layer\(opacity: ([\d.]+), radius: ([\d.]+), offsetY: (-?[\d.]+)\)`;
  for (const row of source.matchAll(new RegExp(String.raw`case \.(e1|e2|sheet): \(${layer}, ${layer}\)`, 'g'))) {
    const [, name = '', cOpacity = '0', cRadius = '0', cY = '0', aOpacity = '0', aRadius = '0', aY = '0'] = row;
    const contact = Number(cOpacity) === 0 ? '' : `0 ${cY}px ${Number(cRadius) * 2}px rgba(${rgb},${cOpacity}), `;
    const spread = name === 'sheet' ? -12 : -Number(aRadius);
    out.push(line(name, `${contact}0 ${aY}px ${Number(aRadius) * 2}px ${spread}px rgba(${rgb},${aOpacity})`));
  }
  return out;
}

function typography(): string[] {
  const source = readToken('Typography.swift');
  const out: string[] = [];
  for (const row of source.matchAll(/static let (\w+) = (?:serif|sans)\((\d+),/g)) {
    out.push(line(`fs-${kebab(row[1] ?? '')}`, rem(Number(row[2]))));
  }
  out.push(line('display-tracking', `${source.match(/displayTracking: CGFloat = (-?[\d.]+)/)?.[1] ?? '-0.015'}em`));
  out.push(line('tall-script-line-height', source.match(/tallScriptMultiplier: CGFloat = ([\d.]+)/)?.[1] ?? '1.15'));
  return out;
}

function motion(): string[] {
  const source = readToken('Motion.swift');
  const out: string[] = [];
  for (const m of source.matchAll(/static let (press|fade|rise|sheet|pop|ring|draw|sheen|glow|pulse|bar) = ([\d.]+)/g)) {
    out.push(line(`dur-${m[1]}`, `${m[2]}s`));
  }
  for (const name of ['ease', 'soft'] as const) {
    const found = source.match(new RegExp(`static func ${name}[\\s\\S]*?timingCurve\\(([\\d.]+), ([\\d.]+), ([\\d.]+), ([\\d.]+)`));
    if (found !== null) out.push(line(name, `cubic-bezier(${[1, 2, 3, 4].map((i) => Number(found[i])).join(',')})`));
  }
  const pick = (pattern: RegExp, fallback: string): string => source.match(pattern)?.[1] ?? fallback;
  out.push(line('rise-offset', `${pick(/riseOffset: CGFloat = (\d+)/, '14')}px`));
  out.push(line('stagger', `${pick(/static let stagger = ([\d.]+)/, '0.04')}s`));
  out.push(line('late-delay', `${pick(/static let lateDelay = ([\d.]+)/, '0.36')}s`));
  out.push(line('bar-delay', `${pick(/static let barDelay = ([\d.]+)/, '0.18')}s`));
  out.push(line('press-scale', pick(/pressScale: CGFloat = ([\d.]+)/, '0.97')));
  out.push(line('press-scale-row', pick(/pressScaleRow: CGFloat = ([\d.]+)/, '0.985')));
  return out;
}

function rule(selector: string, lines: readonly string[]): string {
  return lines.length === 0 ? '' : `${selector} {\n${lines.join('\n')}\n}\n`;
}

function indent(text: string): string {
  return text
    .split('\n')
    .map((row) => (row === '' ? row : `  ${row}`))
    .join('\n');
}

const appearance = colors();
const spacing = parseNumbers(readToken('Spacing.swift')).map(([name, value]) => line(`space-${kebab(name)}`, `${value}px`));
const radius = parseNumbers(readToken('Radius.swift')).map(([name, value]) => line(`radius-${kebab(name)}`, `${value}px`));

const output = `/* Generated by scripts/gen-tokens.ts from BelloHub/DesignSystem/Tokens/*.swift. Do not edit. */

${rule(':root', [...appearance.light, ...hero(), ...spacing, ...radius, ...shadows(), ...typography(), ...motion(), '  color-scheme: light;'])}
/* Order matters: the dark rules come after the light increased-contrast ones and override them in dark mode. */
@media (prefers-contrast: more) {
${indent(rule(':root', appearance.lightMore))}}
@media (prefers-color-scheme: dark) {
${indent(rule(':root', [...appearance.dark, '  color-scheme: dark;']))}}
@media (prefers-color-scheme: dark) and (prefers-contrast: more) {
${indent(rule(':root', appearance.darkMore))}}
`;

mkdirSync(dirname(target), { recursive: true });
writeFileSync(target, output);
