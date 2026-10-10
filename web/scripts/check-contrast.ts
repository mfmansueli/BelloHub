// Measures every text/background pair the web CSS uses, straight from the iOS palette (the one source), in light,
// dark and both with Increase Contrast (`prefers-contrast: more`). WCAG 2.2 AA: text at least 4.5:1, UI parts and
// informative icons at least 3:1 (CLAUDE.md section 5, docs/10 section 6). Exits non-zero on any failure.
//
//   npx tsx scripts/check-contrast.ts          prints the table, fails on a pair below its minimum
//   npx tsx scripts/check-contrast.ts --quiet  prints only failures and the totals

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  blend,
  contrastRatio,
  kebab,
  parseAvatar,
  parseColors,
  readToken,
  type ColorToken,
} from './lib/swift-tokens';

type Mode = 'light' | 'dark' | 'lightIncreased' | 'darkIncreased';
const MODES: readonly Mode[] = ['light', 'dark', 'lightIncreased', 'darkIncreased'];

const palette = parseColors(readToken('Palette.swift'));
const hero = parseColors(readToken('HeroPalette.swift'));
const avatar = parseAvatar(readToken('AvatarPalette.swift'));
const byName = new Map<string, ColorToken>(palette.map((c) => [c.name, c]));
const heroByName = new Map<string, ColorToken>(hero.map((c) => [c.name, c]));

function color(name: string, mode: Mode): string {
  const token = byName.get(name);
  if (token === undefined) throw new Error(`unknown token ${name}`);
  return token[mode];
}

interface Pair {
  readonly role: 'text' | 'large text' | 'ui';
  readonly foreground: string;
  readonly background: string;
  readonly why: string;
}

// Text pairs the CSS uses (src/styles/*.css). Keep in step with the stylesheet: a pair that is not here is not measured.
const PAIRS: readonly Pair[] = [
  { role: 'text', foreground: 'ink', background: 'bg', why: 'body text on the page' },
  { role: 'text', foreground: 'ink', background: 'surface', why: 'text in cards and sheets' },
  { role: 'text', foreground: 'ink', background: 'sunken', why: 'inputs, wells, segmented controls' },
  { role: 'text', foreground: 'ink2', background: 'bg', why: 'secondary text on the page' },
  { role: 'text', foreground: 'ink2', background: 'surface', why: 'secondary text in cards' },
  { role: 'text', foreground: 'ink2', background: 'sunken', why: 'secondary text in wells' },
  { role: 'text', foreground: 'onAction', background: 'action', why: 'primary button, checked checkbox, skip link, avatar' },
  { role: 'text', foreground: 'selectionInk', background: 'selectionFill', why: 'selected chip, day, slot and date' },
  { role: 'text', foreground: 'roseText', background: 'bg', why: 'links and action text on the page' },
  { role: 'text', foreground: 'roseText', background: 'surface', why: 'links in cards' },
  { role: 'text', foreground: 'roseDeepText', background: 'roseWash', why: '"next up" chip' },
  { role: 'text', foreground: 'roseDeepText', background: 'roseDeepWash', why: 'chip on a rose wash' },
  { role: 'text', foreground: 'sageText', background: 'sageWash', why: '"confirmed" chip, success text' },
  { role: 'text', foreground: 'sageText', background: 'surface', why: 'check marks and success lines in cards' },
  { role: 'text', foreground: 'sageText', background: 'bg', why: 'success text on the page' },
  { role: 'text', foreground: 'peachText', background: 'peachWash', why: 'warm tiles' },
  { role: 'text', foreground: 'amberText', background: 'amberBg', why: '"pending" chip and warnings' },
  { role: 'text', foreground: 'coralText', background: 'coralBg', why: 'safety notices' },
  { role: 'text', foreground: 'coralText', background: 'surface', why: 'destructive row title' },
  { role: 'text', foreground: 'neutralText', background: 'neutralWash', why: 'quiet chips' },
  { role: 'ui', foreground: 'fieldBorder', background: 'bg', why: 'input border on the page (WCAG 1.4.11)' },
  { role: 'ui', foreground: 'fieldBorder', background: 'surface', why: 'secondary button and input border in a card' },
  { role: 'ui', foreground: 'ink3', background: 'surface', why: 'informative icons (chevrons)' },
  { role: 'ui', foreground: 'ink3', background: 'bg', why: 'informative icons on the page' },
  { role: 'ui', foreground: 'roseText', background: 'bg', why: 'focus ring (3 px roseText)' },
  { role: 'ui', foreground: 'sage', background: 'surface', why: 'success graphics' },
  { role: 'ui', foreground: 'selectionInk', background: 'surface', why: 'selected radio, option outline, chip and slot ring' },
  { role: 'ui', foreground: 'selectionInk', background: 'bg', why: 'selected day ring on the page' },
  { role: 'ui', foreground: 'action', background: 'bg', why: 'filled progress segments' },
];

interface Result {
  readonly mode: Mode;
  readonly pair: string;
  readonly why: string;
  readonly ratio: number;
  readonly minimum: number;
}

const results: Result[] = [];

function record(mode: Mode, pair: string, why: string, ratio: number, minimum: number): void {
  results.push({ mode, pair, why, ratio, minimum });
}

for (const mode of MODES) {
  for (const pair of PAIRS) {
    const minimum = pair.role === 'ui' || pair.role === 'large text' ? 3 : 4.5;
    record(mode, `${kebab(pair.foreground)} on ${kebab(pair.background)}`, pair.why, contrastRatio(color(pair.foreground, mode), color(pair.background, mode)), minimum);
  }

  // Avatar initials on both ends of their gradient.
  for (const kind of Object.keys(avatar.text)) {
    const text = avatar.text[kind]?.[mode];
    for (const end of ['start', 'end'] as const) {
      const background = avatar[end][kind]?.[mode];
      if (text !== undefined && background !== undefined) {
        record(mode, `avatar ${kind} initials on ${end}`, 'avatar', contrastRatio(text, background), 4.5);
      }
    }
  }
}

// The hero is graphite in every appearance: measure at the lightest point of the glow, not the average.
const heroColor = (name: string): string => heroByName.get(name)?.light ?? '';
const gradientStart = heroColor('gradientStart');
const roseGlow = Number(readToken('HeroPalette.swift').match(/glowRoseOpacity = ([\d.]+)/)?.[1] ?? 0.3);
const sageGlow = Number(readToken('HeroPalette.swift').match(/glowSageOpacity = ([\d.]+)/)?.[1] ?? 0.22);
for (const [glow, alpha] of [['glowRose', roseGlow], ['glowSage', sageGlow]] as const) {
  const worst = blend(heroColor(glow), gradientStart, alpha);
  record('light', `hero ink on ${glow} peak`, 'hero text', contrastRatio(heroColor('ink'), worst), 4.5);
  record('light', `hero ink2 on ${glow} peak`, 'hero secondary text', contrastRatio(heroColor('ink2'), worst), 4.5);
}

// Static rule: the CSS may not set `color` to a token that is not for text (docs/08 section 2).
const NOT_FOR_TEXT = ['--ink-3', '--rose', '--sage', '--peach', '--hairline'];
const stylesDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '../src');
function cssFiles(directory: string): string[] {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    if (statSync(path).isDirectory()) return cssFiles(path);
    return path.endsWith('.css') && !path.endsWith('.generated.css') ? [path] : [];
  });
}
const misuse: string[] = [];
for (const file of cssFiles(stylesDirectory)) {
  const text = readFileSync(file, 'utf8');
  for (const name of NOT_FOR_TEXT) {
    if (new RegExp(`(^|[;{\\s])color:\\s*var\\(${name}\\)`, 'm').test(text)) misuse.push(`${file}: color uses ${name}, which is not a text token`);
  }
  if (/color:\s*rgba?\(/.test(text) || /[^-]color:\s*#[0-9a-fA-F]{3,8}/.test(text)) misuse.push(`${file}: a literal color is set on text; use a token`);
}

const failures = results.filter((r) => r.ratio < r.minimum);
const quiet = process.argv.includes('--quiet');
if (!quiet) {
  for (const result of results) {
    const mark = result.ratio >= result.minimum ? 'ok  ' : 'FAIL';
    process.stdout.write(`${mark} ${result.mode.padEnd(15)} ${result.pair.padEnd(40)} ${result.ratio.toFixed(2).padStart(5)}:1 (min ${result.minimum})\n`);
  }
}
for (const failure of failures) {
  process.stderr.write(`FAIL ${failure.mode} ${failure.pair}: ${failure.ratio.toFixed(2)}:1, needs ${failure.minimum}:1 (${failure.why})\n`);
}
for (const problem of misuse) process.stderr.write(`FAIL ${problem}\n`);
process.stdout.write(`contrast: ${results.length - failures.length}/${results.length} pairs pass in light, dark and Increase Contrast; ${misuse.length} CSS misuses\n`);
process.exit(failures.length > 0 || misuse.length > 0 ? 1 : 0);
