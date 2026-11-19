/**
 * Fokus tasarım token'ları — TEK KAYNAK (TypeScript tarafı).
 *
 * `tokens.css` aynı değerleri `--fk-*` CSS değişkenleri olarak taşır; `tokens.test.ts` ikisinin
 * senkron olduğunu doğrular. SwiftUI'a taşırken her renk bir Asset Catalog rengi olur
 * (`Color("SecondaryLabel")`), tipografi ölçeği `.font(.headline)` gibi Dynamic Type stillerine,
 * boşluklar 4pt ızgarasına karşılık gelir.
 */

export type ThemeName = 'light' | 'dark'

export const COLOR_TOKENS = [
  'background',
  'surface',
  'surface-elevated',
  'fill',
  'control-thumb',
  'label',
  'secondary-label',
  'tertiary-label',
  'separator',
  'accent',
  'accent-contrast',
  'accent-subtle',
  'success',
  'warning',
  'danger',
  'danger-subtle',
  'scrim',
] as const

export type ColorToken = (typeof COLOR_TOKENS)[number]

/** Hex değerleri (`#RRGGBB` veya alfa'lı `#RRGGBBAA`). */
export const COLORS: Readonly<Record<ThemeName, Readonly<Record<ColorToken, string>>>> = {
  light: {
    background: '#F2F2F7',
    surface: '#FFFFFF',
    'surface-elevated': '#FFFFFF',
    fill: '#E3E3E8',
    'control-thumb': '#FFFFFF',
    label: '#1C1C1E',
    'secondary-label': '#5F5F66',
    'tertiary-label': '#7C7C82',
    separator: '#C6C6C8',
    accent: '#4B48D6',
    'accent-contrast': '#FFFFFF',
    'accent-subtle': '#E9E8FB',
    success: '#1F7A35',
    warning: '#A35200',
    danger: '#C9001A',
    'danger-subtle': '#FCE8EA',
    scrim: '#00000066',
  },
  dark: {
    background: '#000000',
    surface: '#1C1C1E',
    'surface-elevated': '#2C2C2E',
    fill: '#38383A',
    'control-thumb': '#636366',
    label: '#FFFFFF',
    'secondary-label': '#AEAEB2',
    'tertiary-label': '#8E8E93',
    separator: '#38383A',
    accent: '#9895FF',
    'accent-contrast': '#0B0A2E',
    'accent-subtle': '#25234D',
    success: '#30D158',
    warning: '#FFB340',
    danger: '#FF6961',
    'danger-subtle': '#3D1C1E',
    scrim: '#00000099',
  },
}

/** SwiftUI Asset Catalog renk adları (PascalCase). */
export function swiftUIColorName(token: ColorToken): string {
  return token
    .split('-')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join('')
}

export interface TextStyle {
  /** Punto (px) cinsinden yazı boyutu. */
  size: number
  lineHeight: number
  weight: 400 | 500 | 600 | 700
  /** SwiftUI karşılığı. */
  swiftUI: string
}

/** iOS Dynamic Type (Large / varsayılan) ölçeği. Tailwind: `text-<ad>` (ör. `text-headline`). */
export const TYPE_SCALE = {
  'large-title': { size: 34, lineHeight: 41, weight: 700, swiftUI: '.largeTitle.bold()' },
  title1: { size: 28, lineHeight: 34, weight: 700, swiftUI: '.title.bold()' },
  title2: { size: 22, lineHeight: 28, weight: 700, swiftUI: '.title2.bold()' },
  title3: { size: 20, lineHeight: 25, weight: 600, swiftUI: '.title3.weight(.semibold)' },
  headline: { size: 17, lineHeight: 22, weight: 600, swiftUI: '.headline' },
  body: { size: 17, lineHeight: 22, weight: 400, swiftUI: '.body' },
  callout: { size: 16, lineHeight: 21, weight: 400, swiftUI: '.callout' },
  subheadline: { size: 15, lineHeight: 20, weight: 400, swiftUI: '.subheadline' },
  footnote: { size: 13, lineHeight: 18, weight: 400, swiftUI: '.footnote' },
  caption: { size: 12, lineHeight: 16, weight: 400, swiftUI: '.caption' },
} as const satisfies Record<string, TextStyle>

export type TextStyleName = keyof typeof TYPE_SCALE

export const FONT_FAMILY =
  '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, "Segoe UI", Roboto, sans-serif'

/** 4pt ızgara: Tailwind `p-1` = 4px, `p-4` = 16px. */
export const SPACING_UNIT = 4

/** Köşe yarıçapları (px). Tailwind: `rounded-sm|md|lg|xl`. */
export const RADII = { sm: 8, md: 12, lg: 16, xl: 22 } as const

/** Minimum dokunma hedefi (px) — Apple HIG 44pt. Tailwind: `min-h-11` / `size-11`. */
export const MIN_HIT_TARGET = 44

/** Kenar çubuğu/tab bar kırılımları (px). Tailwind `md` ve `lg` ile aynıdır. */
export const BREAKPOINTS = { md: 768, lg: 1024 } as const

/** Metin/ikon rengi + üzerinde durduğu arka plan; kontrast testi bu listeyi kullanır. */
export interface ContrastPair {
  foreground: ColorToken
  background: ColorToken
  /** 4.5 = normal metin (AA), 3 = büyük metin veya UI ikonları (AA). */
  minRatio: 4.5 | 3
}

const TEXT_ON_BASES: readonly ColorToken[] = ['background', 'surface', 'surface-elevated']

function textPairs(foreground: ColorToken, minRatio: 4.5 | 3): ContrastPair[] {
  return TEXT_ON_BASES.map((background) => ({ foreground, background, minRatio }))
}

export const CONTRAST_PAIRS: readonly ContrastPair[] = [
  ...textPairs('label', 4.5),
  ...textPairs('secondary-label', 4.5),
  ...textPairs('accent', 4.5),
  ...textPairs('success', 4.5),
  ...textPairs('warning', 4.5),
  ...textPairs('danger', 4.5),
  // tertiary-label yalnızca ikon/chevron/devre dışı içerik içindir (UI glyph, 3:1).
  ...textPairs('tertiary-label', 3),
  { foreground: 'label', background: 'fill', minRatio: 4.5 },
  { foreground: 'secondary-label', background: 'fill', minRatio: 4.5 },
  { foreground: 'label', background: 'control-thumb', minRatio: 4.5 },
  { foreground: 'accent-contrast', background: 'accent', minRatio: 4.5 },
  { foreground: 'accent', background: 'accent-subtle', minRatio: 4.5 },
  { foreground: 'danger', background: 'danger-subtle', minRatio: 4.5 },
]
