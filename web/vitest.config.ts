import preact from '@preact/preset-vite';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [preact()],
  test: {
    include: ['test/unit/**/*.test.ts', 'test/unit/**/*.test.tsx'],
    environment: 'node',
    testTimeout: 30_000,
    coverage: { provider: 'v8', include: ['src/**'], reporter: ['text-summary'] },
  },
});
