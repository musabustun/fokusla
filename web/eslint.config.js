// @ts-check
import js from '@eslint/js'
import prettier from 'eslint-config-prettier'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import globals from 'globals'
import tseslint from 'typescript-eslint'

/**
 * Modül sınırları (bkz. /CLAUDE.md → "Modül sınırları").
 * Her özellik (feature) yalnızca kendi klasörünü, ortak katmanları (ui, domain, data, curriculum)
 * ve app/routes'u import edebilir. Bir feature başka bir feature'ı import EDEMEZ.
 */
const FEATURES = [
  'today',
  'focus',
  'analysis',
  'books',
  'tasks',
  'social',
  'settings',
  'onboarding',
]

/** Dexie'ye yalnızca veri katmanı dokunur. */
const DEXIE_ONLY_IN_DATA = {
  group: ['dexie', 'dexie-react-hooks'],
  message: "Dexie'yi doğrudan kullanma; @/data üzerinden repository ve hook'ları kullan.",
}

/** Veri katmanının iç detayları dışarıya kapalıdır; yalnızca @/data (index.ts) public API'dir. */
const DATA_INTERNALS = {
  group: ['@/data/*'],
  message: 'Veri katmanını yalnızca "@/data" public API\'si üzerinden import et.',
}

/** @param {string} feature */
const featureBoundary = (feature) => ({
  files: [`src/features/${feature}/**/*.{ts,tsx}`],
  rules: {
    'no-restricted-imports': [
      'error',
      {
        patterns: [
          {
            group: ['@/features/*', `!@/features/${feature}`, `!@/features/${feature}/**`],
            message:
              "Bir feature başka bir feature'ı import edemez. Ortak kodu @/ui, @/domain veya @/data'ya taşı.",
          },
          {
            group: ['@/app/*', '!@/app/routes'],
            message: "Feature'lar @/app altından yalnızca @/app/routes'u import edebilir.",
          },
          DEXIE_ONLY_IN_DATA,
          DATA_INTERNALS,
        ],
      },
    ],
  },
})

export default tseslint.config(
  { ignores: ['dist', 'coverage', 'playwright-report', 'test-results'] },
  {
    extends: [js.configs.recommended, ...tseslint.configs.strict, ...tseslint.configs.stylistic],
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      ecmaVersion: 2023,
      globals: globals.browser,
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      'no-console': ['error', { allow: ['warn', 'error'] }],
    },
  },
  {
    files: ['*.config.{ts,js}', 'e2e/**/*.ts'],
    languageOptions: { globals: globals.node },
  },
  {
    files: ['**/*.test.{ts,tsx}', 'src/test/**/*.{ts,tsx}'],
    rules: { 'react-refresh/only-export-components': 'off' },
  },

  // --- Katman sınırları ---
  ...FEATURES.map(featureBoundary),
  {
    files: ['src/ui/**/*.{ts,tsx}'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: ['@/features/*', '@/data', '@/data/*', '@/app/*', '@/curriculum/*'],
              message:
                'Tasarım sistemi (ui) bağımsızdır: yalnızca kendi dosyalarını ve @/domain tiplerini kullanabilir.',
            },
            DEXIE_ONLY_IN_DATA,
          ],
        },
      ],
    },
  },
  {
    files: ['src/domain/**/*.ts'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: ['react', 'react-dom', 'react-router', 'zustand', '@/*', '!@/domain'],
              message:
                "domain katmanı saf TypeScript'tir: framework veya diğer katmanları import edemez.",
            },
            DEXIE_ONLY_IN_DATA,
          ],
        },
      ],
    },
  },
  {
    files: ['src/curriculum/**/*.ts'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: ['react', '@/*', '!@/domain', '!@/curriculum'],
              message: 'curriculum yalnızca @/domain tiplerine bağımlı saf veridir.',
            },
            DEXIE_ONLY_IN_DATA,
          ],
        },
      ],
    },
  },
  {
    files: ['src/data/**/*.{ts,tsx}'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: ['@/features/*', '@/ui', '@/ui/*', '@/app/*'],
              message: 'Veri katmanı UI, app veya feature kodunu import edemez.',
            },
          ],
        },
      ],
    },
  },
  {
    files: ['src/app/**/*.{ts,tsx}'],
    rules: {
      'no-restricted-imports': ['error', { patterns: [DEXIE_ONLY_IN_DATA, DATA_INTERNALS] }],
    },
  },
  prettier,
)
