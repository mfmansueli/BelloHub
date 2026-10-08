// Build plugin: Subresource Integrity on the entry script and stylesheet, and the published bundle hashes.
//
// - `integrity="sha384-..."` on every <script> and <link> that index.html loads (docs/06 section 6). There is no
//   external-looking asset, so this guards against a corrupted or swapped file on the CDN edge. The hashes are
//   computed from the files on disk after the whole build wrote them: Vite still rewrites chunk code late in the
//   build, so hashing earlier would not match what is served.
// - `dist/.well-known/bellohub-build.txt` lists the SHA-256 of every file and one hash over the list, so anyone can
//   compare what a page served with what the build published (docs/06 section 6, "bundle hash is published").

import { createHash } from 'node:crypto';
import { mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import type { Plugin } from 'vite';

function integrityOf(content: Buffer): string {
  return `sha384-${createHash('sha384').update(content).digest('base64')}`;
}

function walk(directory: string): string[] {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

export function integrityPlugin(): Plugin {
  let outDir = 'dist';
  return {
    name: 'bellohub-integrity',
    apply: 'build',
    configResolved(config) {
      outDir = config.build.outDir;
    },
    writeBundle() {
      const indexPath = join(outDir, 'index.html');
      const html = readFileSync(indexPath, 'utf8').replace(/<(script|link)\b([^>]*?)(src|href)="\/(assets\/[^"]+)"([^>]*)>/g, (tag, name: string, before: string, attribute: string, file: string, after: string) => {
        if (/\bintegrity=/.test(tag)) return tag;
        return `<${name}${before}${attribute}="/${file}"${after} integrity="${integrityOf(readFileSync(join(outDir, file)))}">`;
      });
      writeFileSync(indexPath, html);

      const files = walk(outDir)
        .map((path) => relative(outDir, path).split('\\').join('/'))
        .filter((path) => !path.startsWith('.well-known/'))
        .sort();
      const lines = files.map((path) => `${createHash('sha256').update(readFileSync(join(outDir, path))).digest('hex')}  ${path}`);
      const bundleHash = createHash('sha256').update(lines.join('\n')).digest('hex');
      const text = `# Bello Hub web bundle. SHA-256 of every file served, then one hash over the list.\n${lines.join('\n')}\nbundle  sha256:${bundleHash}\n`;
      mkdirSync(join(outDir, '.well-known'), { recursive: true });
      writeFileSync(join(outDir, '.well-known', 'bellohub-build.txt'), text);
    },
  };
}
