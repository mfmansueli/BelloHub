import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: [
      'dist/**',
      'node_modules/**',
      'playwright-report/**',
      'test-results/**',
      'coverage/**',
      '.lighthouseci/**',
      'src/lib/regions.generated.ts',
      'src/legal/generated/**',
      'test/vectors/generate/**',
      '**/*.js',
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.json', './tsconfig.node.json'],
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      // `any` needs a comment saying why: use a targeted eslint-disable with the reason.
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-non-null-assertion': 'error',
      '@typescript-eslint/restrict-template-expressions': ['error', { allowNumber: true }],
      '@typescript-eslint/no-confusing-void-expression': ['error', { ignoreArrowShorthand: true }],
      '@typescript-eslint/no-unnecessary-condition': 'error',
      // Never log: a log line is where personal data and tokens leak (docs/06 section 8).
      'no-console': 'error',
      'no-restricted-syntax': [
        'error',
        {
          selector: "JSXAttribute[name.name='dangerouslySetInnerHTML']",
          message: 'Professional-supplied text is never rendered as HTML (docs/10 section 6).',
        },
        { selector: "MemberExpression[property.name='innerHTML']", message: 'Never assign HTML: render text nodes.' },
        { selector: "MemberExpression[property.name='outerHTML']", message: 'Never assign HTML: render text nodes.' },
        { selector: "CallExpression[callee.name='eval']", message: 'No eval.' },
        { selector: "NewExpression[callee.name='Function']", message: 'No dynamic code.' },
      ],
    },
  },
  {
    // Test code runs in Node and may log, use tuples and non-null assertions on fixtures.
    files: ['test/**/*.ts', 'test/**/*.tsx', 'scripts/**/*.ts', 'playwright.config.ts', 'vite.config.ts', 'vitest.config.ts'],
    rules: {
      'no-console': 'off',
      '@typescript-eslint/no-non-null-assertion': 'off',
      '@typescript-eslint/no-unnecessary-condition': 'off',
    },
  },
);
