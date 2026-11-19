/**
 * Fokus tasarım token'ları — TEK KAYNAK (TypeScript tarafı).
 *
 * `tokens.css` aynı değerleri `--fk-*` CSS değişkenleri olarak taşır; `tokens.test.ts` ikisinin
 * senkron olduğunu doğrular. SwiftUI'a taşırken her renk bir Asset Catalog rengi olur
 * (`Color("SecondaryLabel")`), tipografi ölçeği `.font(.headline)` gibi Dynamic Type stillerine,
 * boşluklar 4pt ızgarasına karşılık gelir.
 */

export type ThemeName = 'light' | 'dark'

/** Varsayılan tema: koyu ("gece"). Açık tema ("gündüz") kullanıcı seçimidir. */
export const DEFAULT_THEME: ThemeName = 'dark'

export const COLOR_TOKENS = [
  'background',
  'surface',
  'surface-elevated',
  'fill',
  'control-thumb',
  'switch-thumb-off',
  'label',
  'secondary-label',
  'tertiary-label',
  'separator',
  'separator-strong',
  'accent',
  'accent-contrast',
  'accent-ink',
  'accent-subtle',
  'success',
  'success-contrast',
  'warning',
  'danger',
  'danger-subtle',
  'scrim',
] as const

export type ColorToken = (typeof COLOR_TOKENS)[number]

/** Hex değerleri (`#RRGGBB` veya alfa'lı `#RRGGBBAA`). */
export const COLORS: Readonly<Record<ThemeName, Readonly<Record<ColorToken, string>>>> = {
  light: {
    background: '#F5F2EA',
    surface: '#FBF9F4',
    'surface-elevated': '#FFFDF8',
    fill: '#E8E3D7',
    'control-thumb': '#1B1A16',
    'switch-thumb-off': '#77736A',
    label: '#1B1A16',
    'secondary-label': '#5C5950',
    'tertiary-label': '#7A766C',
    separator: '#DCD6C9',
    'separator-strong': '#8C877B',
    accent: '#FFB547',
    'accent-contrast': '#1A1205',
    'accent-ink': '#955500',
    'accent-subtle': '#F8E5C0',
    success: '#2D6A43',
    'success-contrast': '#FFFFFF',
    warning: '#955500',
    danger: '#B3261E',
    'danger-subtle': '#F7E1DC',
    scrim: '#1B1A1666',
  },
  dark: {
    background: '#0E0F0C',
    surface: '#141511',
    'surface-elevated': '#1A1B17',
    fill: '#22231E',
    'control-thumb': '#EDEAE2',
    'switch-thumb-off': '#8A877F',
    label: '#EDEAE2',
    'secondary-label': '#9A978E',
    'tertiary-label': '#6F6C64',
    separator: '#2A2A25',
    'separator-strong': '#6A675F',
    accent: '#FFB547',
    'accent-contrast': '#1A1205',
    'accent-ink': '#FFB547',
    'accent-subtle': '#2A2214',
    success: '#8FD3A6',
    'success-contrast': '#0B1A10',
    warning: '#FFB547',
    danger: '#FF7A6B',
    'danger-subtle': '#2C1613',
    scrim: '#000000B3',
  },
}

/** SwiftUI Asset Catalog renk adları (PascalCase). */
export function swiftUIColorName(token: ColorToken): string {
  return token
    .split('-')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join('')
}

export type FontRole = 'display' | 'text' | 'mono'

export interface TextStyle {
  /** Punto (px) cinsinden yazı boyutu. */
  size: number
  lineHeight: number
  weight: 400 | 500 | 600 | 700 | 800
  /** Yazı ailesi rolü (bkz. FONT_FAMILIES). */
  font: FontRole
  /** em cinsinden harf aralığı (negatif = sıkı). */
  tracking: number
  /** SwiftUI karşılığı. */
  swiftUI: string
}

/**
 * "Gece mesaisi" yazı ölçeği. Tailwind: `text-<ad>` (ör. `text-large-title`). Başlıklar
 * (`h1`–`h3`) otomatik olarak Bricolage Grotesque alır; rakamlar `numeric text-numeral-*`.
 */
export const TYPE_SCALE = {
  display: {
    size: 44,
    lineHeight: 48,
    weight: 800,
    font: 'display',
    tracking: -0.04,
    swiftUI: '.custom("BricolageGrotesque-ExtraBold", size: 44, relativeTo: .largeTitle)',
  },
  'large-title': {
    size: 36,
    lineHeight: 40,
    weight: 800,
    font: 'display',
    tracking: -0.035,
    swiftUI: '.custom("BricolageGrotesque-ExtraBold", size: 36, relativeTo: .largeTitle)',
  },
  title1: {
    size: 28,
    lineHeight: 32,
    weight: 800,
    font: 'display',
    tracking: -0.03,
    swiftUI: '.custom("BricolageGrotesque-ExtraBold", size: 28, relativeTo: .title)',
  },
  title2: {
    size: 22,
    lineHeight: 28,
    weight: 500,
    font: 'display',
    tracking: -0.02,
    swiftUI: '.custom("BricolageGrotesque-Medium", size: 22, relativeTo: .title2)',
  },
  title3: {
    size: 20,
    lineHeight: 24,
    weight: 500,
    font: 'display',
    tracking: -0.015,
    swiftUI: '.custom("BricolageGrotesque-Medium", size: 20, relativeTo: .title3)',
  },
  headline: {
    size: 17,
    lineHeight: 22,
    weight: 600,
    font: 'text',
    tracking: 0,
    swiftUI: '.headline',
  },
  body: { size: 17, lineHeight: 24, weight: 400, font: 'text', tracking: 0, swiftUI: '.body' },
  callout: {
    size: 16,
    lineHeight: 22,
    weight: 400,
    font: 'text',
    tracking: 0,
    swiftUI: '.callout',
  },
  subheadline: {
    size: 15,
    lineHeight: 20,
    weight: 400,
    font: 'text',
    tracking: 0,
    swiftUI: '.subheadline',
  },
  footnote: {
    size: 13,
    lineHeight: 18,
    weight: 400,
    font: 'text',
    tracking: 0,
    swiftUI: '.footnote',
  },
  caption: {
    size: 12,
    lineHeight: 16,
    weight: 400,
    font: 'text',
    tracking: 0,
    swiftUI: '.caption',
  },
  eyebrow: {
    size: 11,
    lineHeight: 16,
    weight: 500,
    font: 'mono',
    tracking: 0.12,
    swiftUI:
      '.custom("JetBrainsMono-Medium", size: 11, relativeTo: .caption2).textCase(.uppercase).tracking(1.3)',
  },
  'numeral-hero': {
    size: 72,
    lineHeight: 72,
    weight: 400,
    font: 'mono',
    tracking: -0.06,
    swiftUI:
      '.custom("JetBrainsMono-Regular", size: 72, relativeTo: .largeTitle).monospacedDigit()',
  },
  'numeral-xl': {
    size: 56,
    lineHeight: 56,
    weight: 400,
    font: 'mono',
    tracking: -0.05,
    swiftUI:
      '.custom("JetBrainsMono-Regular", size: 56, relativeTo: .largeTitle).monospacedDigit()',
  },
  'numeral-lg': {
    size: 36,
    lineHeight: 40,
    weight: 400,
    font: 'mono',
    tracking: -0.04,
    swiftUI: '.custom("JetBrainsMono-Regular", size: 36, relativeTo: .title).monospacedDigit()',
  },
  numeral: {
    size: 24,
    lineHeight: 30,
    weight: 400,
    font: 'mono',
    tracking: -0.03,
    swiftUI: '.custom("JetBrainsMono-Regular", size: 24, relativeTo: .title2).monospacedDigit()',
  },
  'numeral-sm': {
    size: 17,
    lineHeight: 22,
    weight: 500,
    font: 'mono',
    tracking: -0.01,
    swiftUI: '.custom("JetBrainsMono-Medium", size: 17, relativeTo: .body).monospacedDigit()',
  },
} as const satisfies Record<string, TextStyle>

export type TextStyleName = keyof typeof TYPE_SCALE

/** Yazı aileleri. Web'de @fontsource-variable ile yerelde barındırılır; iOS'ta uygulamaya gömülür. */
export const FONT_FAMILIES: Readonly<Record<FontRole, string>> = {
  display: '"Bricolage Grotesque Variable", "Bricolage Grotesque", system-ui, sans-serif',
  text: '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, "Segoe UI", Roboto, sans-serif',
  mono: '"JetBrains Mono Variable", "JetBrains Mono", ui-monospace, "SF Mono", Menlo, monospace',
}

/** Geriye dönük uyumluluk: gövde yazı ailesi. */
export const FONT_FAMILY = FONT_FAMILIES.text

/** 4pt ızgara: Tailwind `p-1` = 4px, `p-4` = 16px. */
export const SPACING_UNIT = 4

/** Köşe yarıçapları (px). Tailwind: `rounded-sm|md|lg|xl`; eylem butonları `rounded-full` (hap). */
export const RADII = { sm: 6, md: 10, lg: 14, xl: 20 } as const

/**
 * Hareket token'ları (ms). Tailwind: `duration-<ms>`, `ease-standard|emphasized`,
 * `animate-screen-in|sheet-in`. `prefers-reduced-motion: reduce` iken hepsi durur.
 * SwiftUI: `.animation(.snappy(duration:))`, `.scaleEffect` basma geri bildirimi.
 */
export const MOTION = {
  /** Basınca küçülme (scale 0.97). */
  press: 120,
  /** Renk/arka plan geçişleri. */
  base: 200,
  /** Ekran girişi (opaklık + 6px yukarı kayma). */
  enter: 240,
  /** Sheet girişi. */
  sheet: 280,
  /** İlerleme halkası/çubuğu akışı. */
  progress: 700,
} as const

export const EASINGS = {
  standard: 'cubic-bezier(0.2, 0, 0, 1)',
  emphasized: 'cubic-bezier(0.16, 1, 0.3, 1)',
} as const

/** Basılı eylemlerin ölçeği (Tailwind `active:scale-97`). */
export const PRESS_SCALE = 0.97

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
  ...textPairs('accent-ink', 4.5),
  ...textPairs('success', 4.5),
  ...textPairs('warning', 4.5),
  ...textPairs('danger', 4.5),
  // tertiary-label yalnızca ikon/chevron/devre dışı içerik içindir (UI glyph, 3:1).
  ...textPairs('tertiary-label', 3),
  // separator-strong: giriş alanı ve çizgili buton sınırı (WCAG 1.4.11, 3:1).
  ...textPairs('separator-strong', 3),
  { foreground: 'label', background: 'fill', minRatio: 4.5 },
  { foreground: 'secondary-label', background: 'fill', minRatio: 4.5 },
  // Seçili segment ters renklidir: zemin rengi metin, control-thumb zemin.
  { foreground: 'background', background: 'control-thumb', minRatio: 4.5 },
  { foreground: 'accent-contrast', background: 'accent', minRatio: 4.5 },
  { foreground: 'success-contrast', background: 'success', minRatio: 4.5 },
  // Switch topuzu rayından ayırt edilmeli (WCAG 1.4.11, 3:1). Açık: accent-contrast/accent (yukarıda).
  { foreground: 'switch-thumb-off', background: 'fill', minRatio: 3 },
  { foreground: 'accent-ink', background: 'accent-subtle', minRatio: 4.5 },
  { foreground: 'danger', background: 'danger-subtle', minRatio: 4.5 },
]
