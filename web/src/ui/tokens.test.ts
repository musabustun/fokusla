import { describe, expect, it } from 'vitest'
import { colorDistance, contrastRatio, parseHex } from './contrast'
import {
  COLOR_TOKENS,
  COLORS,
  CONTRAST_PAIRS,
  DEFAULT_PALETTE,
  isPaletteName,
  PALETTE_LABELS,
  PALETTE_NAMES,
  PALETTES,
  swiftUIColorName,
  swiftUIPaletteColorName,
  type PaletteName,
  type ThemeName,
} from './tokens'

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
async function readProjectFile(path: string): Promise<string> {
  const specifiers = ['node:fs', 'node:process']
  const [fs, process] = (await Promise.all(
    specifiers.map((specifier) => import(/* @vite-ignore */ specifier)),
  )) as [NodeFs, NodeProcess]
  return fs.readFileSync(`${process.cwd()}/${path}`, 'utf8')
}

const tokensCss = await readProjectFile('src/ui/tokens.css')
const indexHtml = await readProjectFile('index.html')

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

function paletteSelector(palette: PaletteName, theme: ThemeName): string {
  if (palette === DEFAULT_PALETTE) {
    return theme === 'light' ? ":root,\n[data-palette='coffee']" : "[data-theme='dark']"
  }
  return theme === 'light'
    ? `[data-palette='${palette}']`
    : `[data-palette='${palette}'][data-theme='dark']`
}

const PALETTE_MODES = PALETTE_NAMES.flatMap((palette) =>
  THEMES.map((theme) => ({ palette, theme })),
)

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
  it.each(PALETTE_MODES)(
    '$palette/$theme: every color token exists as a matching --fk-* variable',
    ({ palette, theme }) => {
      const block = cssBlock(paletteSelector(palette, theme))
      for (const token of COLOR_TOKENS) {
        expect(cssVar(block, token)?.toUpperCase(), token).toBe(PALETTES[palette][theme][token])
      }
    },
  )

  it('keeps COLORS as the default (Kahve) palette', () => {
    expect(DEFAULT_PALETTE).toBe('coffee')
    expect(COLORS).toBe(PALETTES.coffee)
  })

  it('maps every color token to a @theme inline Tailwind color', () => {
    for (const token of COLOR_TOKENS) {
      expect(tokensCss).toContain(`--color-${token}: var(--fk-${token});`)
    }
  })

  it('derives PascalCase SwiftUI asset names', () => {
    expect(swiftUIColorName('secondary-label')).toBe('SecondaryLabel')
    expect(swiftUIPaletteColorName('strawberry', 'accent-ink')).toBe('Strawberry/AccentInk')
  })
})

describe('palettes', () => {
  it('has a Turkish label for every palette, including Tek renk', () => {
    expect(PALETTE_NAMES.map((palette) => PALETTE_LABELS[palette])).toEqual([
      'Kahve',
      'Tek renk',
      'Çilek',
      'Matcha',
      'Yaban mersini',
      'Limonata',
    ])
  })

  it('lists the same palettes in the index.html first-paint script', () => {
    const list = PALETTE_NAMES.map((palette) => `'${palette}'`).join(', ')
    expect(indexHtml).toContain(`var palettes = [${list}]`)
    expect(indexHtml).toContain(`: '${DEFAULT_PALETTE}'`)
  })

  it('validates palette names', () => {
    expect(isPaletteName('matcha')).toBe(true)
    expect(isPaletteName('grape')).toBe(false)
    expect(isPaletteName(null)).toBe(false)
  })

  it.each(PALETTE_MODES)('$palette/$theme: dark is darker than light', ({ palette, theme }) => {
    const background = PALETTES[palette][theme].background
    const other = PALETTES[palette][theme === 'light' ? 'dark' : 'light'].background
    const ratio = contrastRatio(background, other)
    expect(ratio).toBeGreaterThan(15)
  })

  // Mola/başarı vurguyla, hata da vurguyla karışmamalı (CIE76 ΔE; ~2.3 = fark edilebilir eşik).
  it.each(PALETTE_MODES)(
    '$palette/$theme: success and danger stay distinct from the accent',
    ({ palette, theme }) => {
      const colors = PALETTES[palette][theme]
      expect(colorDistance(colors.success, colors['accent-ink'])).toBeGreaterThanOrEqual(30)
      expect(colorDistance(colors.danger, colors['accent-ink'])).toBeGreaterThanOrEqual(30)
    },
  )

  it('Tek renk has a neutral (gray) accent and progress arc', () => {
    for (const theme of THEMES) {
      const [r, g, b] = parseHex(PALETTES.mono[theme]['accent-ink'])
      expect(r).toBe(g)
      expect(g).toBe(b)
    }
  })
})

describe('WCAG AA contrast', () => {
  const cases = PALETTE_MODES.flatMap(({ palette, theme }) =>
    CONTRAST_PAIRS.map((pair) => ({ palette, theme, ...pair })),
  )

  it.each(cases)(
    '$palette/$theme: $foreground on $background ≥ $minRatio',
    ({ palette, theme, foreground, background, minRatio }) => {
      const colors = PALETTES[palette][theme]
      expect(contrastRatio(colors[foreground], colors[background])).toBeGreaterThanOrEqual(minRatio)
    },
  )
})
