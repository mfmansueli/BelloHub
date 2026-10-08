// Reads the iOS design tokens (the one source) so the web can generate CSS from them and measure their contrast.

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const TOKENS_DIRECTORY = resolve(here, '../../../BelloHub/DesignSystem/Tokens');

export function readToken(name: string): string {
  return readFileSync(resolve(TOKENS_DIRECTORY, name), 'utf8');
}

export interface ColorToken {
  readonly name: string;
  readonly light: string;
  readonly dark: string;
  readonly lightIncreased: string;
  readonly darkIncreased: string;
}

export function hex(value: string): string {
  return `#${value.replace(/^0x/i, '').toUpperCase().padStart(6, '0')}`;
}

export function kebab(name: string): string {
  return name.replace(/([a-z0-9])([A-Z])/g, '$1-$2').replace(/([a-zA-Z])(\d)/g, '$1-$2').toLowerCase();
}

function hexFields(body: string): Record<string, string> {
  const fields: Record<string, string> = {};
  for (const field of body.matchAll(/(\w+):\s*(0x[0-9A-Fa-f]+)/g)) {
    fields[field[1] ?? ''] = hex(field[2] ?? '');
  }
  return fields;
}

function toToken(name: string, fields: Record<string, string>): ColorToken | null {
  const single = fields['hex'];
  if (single !== undefined) {
    return { name, light: single, dark: single, lightIncreased: single, darkIncreased: single };
  }
  const light = fields['light'];
  const dark = fields['dark'];
  if (light === undefined || dark === undefined) return null;
  return {
    name,
    light,
    dark,
    lightIncreased: fields['lightIncreased'] ?? light,
    darkIncreased: fields['darkIncreased'] ?? dark,
  };
}

/** `static let x = Color(light: 0x.., dark: 0x.., lightIncreased: 0x.., darkIncreased: 0x..)` and `Color(hex: 0x..)`. */
export function parseColors(source: string): ColorToken[] {
  const found: ColorToken[] = [];
  for (const match of source.matchAll(/static let (\w+) = Color\(([^)]*)\)/g)) {
    const token = toToken(match[1] ?? '', hexFields(match[2] ?? ''));
    if (token !== null) found.push(token);
  }
  return found;
}

/** The avatar gradient pairs: `case .rose: Color(light: .., dark: ..)` inside `var start/end/text`. */
export function parseAvatar(source: string): Record<'start' | 'end' | 'text', Record<string, ColorToken>> {
  const result: Record<'start' | 'end' | 'text', Record<string, ColorToken>> = { start: {}, end: {}, text: {} };
  for (const part of ['start', 'end', 'text'] as const) {
    const section = source.match(new RegExp(`var ${part}: Color \\{([\\s\\S]*?)\\n    \\}`))?.[1] ?? '';
    for (const row of section.matchAll(/case \.(\w+): Color\(([^)]*)\)/g)) {
      const token = toToken(`${row[1] ?? ''}-${part}`, hexFields(row[2] ?? ''));
      if (token !== null) result[part][row[1] ?? ''] = token;
    }
  }
  return result;
}

/** Aliases in Palette that point at another token (`static let accent = roseText`). */
export function parseAliases(source: string): [string, string][] {
  return [...source.matchAll(/static let (\w+) = (\w+)\s*$/gm)].map((m) => [m[1] ?? '', m[2] ?? '']);
}

export function parseNumbers(source: string): [string, number][] {
  return [...source.matchAll(/static let (\w+): CGFloat = ([\d.]+)/g)].map((m) => [m[1] ?? '', Number(m[2])]);
}

// MARK: - Contrast (WCAG 2.2, relative luminance)

function channel(value: number): number {
  const c = value / 255;
  return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
}

export function luminance(color: string): number {
  const value = parseInt(color.replace('#', ''), 16);
  return 0.2126 * channel((value >> 16) & 255) + 0.7152 * channel((value >> 8) & 255) + 0.0722 * channel(value & 255);
}

export function contrastRatio(a: string, b: string): number {
  const [lighter, darker] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return ((lighter ?? 0) + 0.05) / ((darker ?? 0) + 0.05);
}

/** Blends `foreground` over `background` at `alpha` (for glows on the hero surface). */
export function blend(foreground: string, background: string, alpha: number): string {
  const f = parseInt(foreground.replace('#', ''), 16);
  const b = parseInt(background.replace('#', ''), 16);
  const mix = (shift: number): number => Math.round(((f >> shift) & 255) * alpha + ((b >> shift) & 255) * (1 - alpha));
  return `#${((mix(16) << 16) | (mix(8) << 8) | mix(0)).toString(16).padStart(6, '0').toUpperCase()}`;
}
