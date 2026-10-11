import { defineConfig } from 'vitest/config';

// Four projects, one per layer of the pyramid in docs/13-TESTING-QUALITY.md:
//  - unit:        pure rules, no emulator
//  - integration: use cases against the Firestore/Auth/Storage emulators (injected clock and fakes)
//  - rules:       firestore.rules with @firebase/rules-unit-testing
//  - transport:   the deployed function entry points through the Functions emulator (callable protocol)
// Files run one after the other because they share one emulator and clear it between tests.
export default defineConfig({
  test: {
    environment: 'node',
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 60_000,
    projects: [
      { extends: true, test: { name: 'unit', include: ['test/unit/**/*.test.ts'] } },
      { extends: true, test: { name: 'integration', include: ['test/integration/**/*.test.ts'] } },
      { extends: true, test: { name: 'rules', include: ['test/rules/**/*.test.ts'] } },
      { extends: true, test: { name: 'transport', include: ['test/transport/**/*.test.ts'], testTimeout: 60_000 } }
    ]
  }
});
