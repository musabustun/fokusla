import { describe, expect, it } from 'vitest'
import { contrastRatio, parseHex } from './contrast'
import { COLOR_TOKENS, COLORS, CONTRAST_PAIRS, swiftUIColorName, type ThemeName } from './tokens'

const THEMES: readonly ThemeName[] = ['light', 'dark']

interface NodeFs {
  readFileSync: (path: string, encoding: 'utf8') => string
}

interface NodeProcess {
  cwd: () => string
}

/**
 * Vitest CSS dosyalarını (?raw dahil) boş döndürür; dosyayı Node ile okuyoruz. Değişken
 * specifier, uygulama tsconfig'ine Node tiplerini eklemeden yüklemeyi sağlar.
 * Vitest proje kökünden (web/) çalıştırılır.
 */
async function readTokensCss(): Promise<string> {
  const specifiers = ['node:fs', 'node:process']
  const [fs, process] = (await Promise.all(
    specifiers.map((specifier) => import(/* @vite-ignore */ specifier)),
  )) as [NodeFs, NodeProcess]
  return fs.readFileSync(`${process.cwd()}/src/ui/tokens.css`, 'utf8')
}

const tokensCss = await readTokensCss()

function cssBlock(selector: string): string {
  const start = tokensCss.indexOf(`${selector} {`)
  const end = tokensCss.indexOf('}', start)
  expect(start).toBeGreaterThanOrEqual(0)
  return tokensCss.slice(start, end)
}

function cssVar(block: string, token: string): string | undefined {
  const match = new RegExp(`--fk-${token}:\\s*(#[0-9a-fA-F]+);`).exec(block)
  return match?.[1]
}

const CSS_BLOCKS: Record<ThemeName, string> = {
  light: cssBlock(':root'),
  dark: cssBlock("[data-theme='dark']"),
}

describe('contrastRatio', () => {
  it('returns 21 for black on white and 1 for identical colors', () => {
    expect(contrastRatio('#000000', '#FFFFFF')).toBeCloseTo(21, 5)
    expect(contrastRatio('#4B48D6', '#4B48D6')).toBe(1)
  })

  it('rejects malformed hex values', () => {
    expect(() => parseHex('blue')).toThrow()
  })
})

describe('tokens.ts ↔ tokens.css', () => {
  it.each(THEMES)('every %s color token exists as a matching --fk-* variable', (theme) => {
    for (const token of COLOR_TOKENS) {
      expect(cssVar(CSS_BLOCKS[theme], token)?.toUpperCase(), token).toBe(COLORS[theme][token])
    }
  })

  it('maps every color token to a @theme inline Tailwind color', () => {
    for (const token of COLOR_TOKENS) {
      expect(tokensCss).toContain(`--color-${token}: var(--fk-${token});`)
    }
  })

  it('derives PascalCase SwiftUI asset names', () => {
    expect(swiftUIColorName('secondary-label')).toBe('SecondaryLabel')
  })
})

describe('WCAG AA contrast', () => {
  const cases = THEMES.flatMap((theme) => CONTRAST_PAIRS.map((pair) => ({ theme, ...pair })))

  it.each(cases)(
    '$theme: $foreground on $background ≥ $minRatio',
    ({ theme, foreground, background, minRatio }) => {
      const ratio = contrastRatio(COLORS[theme][foreground], COLORS[theme][background])
      expect(ratio).toBeGreaterThanOrEqual(minRatio)
    },
  )
})
