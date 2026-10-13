import { defineConfig } from 'vitest/config';

// Opt-in product guarantees under investigation, separate from the shipping regression suites.
export default defineConfig({
  test: {
    environment: 'node',
    include: ['test/audit/**/*.test.ts'],
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 60_000
  }
});
