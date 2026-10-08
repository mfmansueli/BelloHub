import preact from '@preact/preset-vite';
import { defineConfig } from 'vite';

import { integrityPlugin } from './scripts/vite-integrity';

export default defineConfig({
  plugins: [preact(), integrityPlugin()],
  build: {
    target: ['es2020', 'chrome87', 'safari14', 'firefox78'],
    outDir: 'dist',
    // Fonts must stay files: the CSP allows `font-src 'self'` and not `data:`.
    assetsInlineLimit: 0,
    cssCodeSplit: false,
    sourcemap: false,
    // No inline polyfill script: the CSP has no 'unsafe-inline' and no hashes to maintain.
    modulePreload: { polyfill: false },
    chunkSizeWarningLimit: 120,
    rollupOptions: {
      output: {
        // The sealing library and the Firebase SDK are only reached through dynamic imports (docs/10 section 1).
        entryFileNames: 'assets/[name]-[hash].js',
        chunkFileNames: 'assets/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash][extname]',
      },
    },
  },
  server: {
    port: 5173,
    // `npm run mock` starts the local API the page talks to in development and tests.
    proxy: { '/api': { target: 'http://127.0.0.1:4010', changeOrigin: false } },
  },
  preview: { port: 4173 },
});
