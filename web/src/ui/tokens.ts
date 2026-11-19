/**
 * Fokus tasarım token'ları — TEK KAYNAK (TypeScript tarafı).
 *
 * `tokens.css` aynı değerleri `--fk-*` CSS değişkenleri olarak taşır; `tokens.test.ts` ikisinin
 * senkron olduğunu doğrular. SwiftUI'a taşırken her renk bir Asset Catalog rengi olur
 * (`Color("SecondaryLabel")`), tipografi ölçeği `.font(.headline)` gibi Dynamic Type stillerine,
 * boşluklar 4pt ızgarasına karşılık gelir.
 */

export type ThemeName = 'light' | 'dark'

/** Kayıtlı tercih ve sistem bilgisi yoksa uygulanan mod: koyu ("gece"). */
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

/**
 * Renk temaları (paletler). Mod (açık/koyu) ile bağımsızdır: `<html data-palette data-theme>`.
 * Her palet zemini ve yüzeyleri de kendi rengine hafifçe çeker; mola/başarı (`success`) vurgudan
 * ayırt edilebilir kalır (Matcha'da mola mavi-camgöbeği). Adlar Türkçe arayüz içindir.
 */
export type PaletteName = 'coffee' | 'mono' | 'strawberry' | 'matcha' | 'blueberry' | 'lemonade'

/** Seçicilerde gösterim sırası. */
export const PALETTE_NAMES: readonly PaletteName[] = [
  'coffee',
  'mono',
  'strawberry',
  'matcha',
  'blueberry',
  'lemonade',
]

/** Varsayılan palet: Kahve ("Gece mesaisi"). `data-palette` yoksa tokens.css bunu uygular. */
export const DEFAULT_PALETTE: PaletteName = 'coffee'

export const PALETTE_LABELS: Readonly<Record<PaletteName, string>> = {
  coffee: 'Kahve',
  mono: 'Tek renk',
  strawberry: 'Çilek',
  matcha: 'Matcha',
  blueberry: 'Yaban mersini',
  lemonade: 'Limonata',
}

export type ColorSet = Readonly<Record<ColorToken, string>>

/** Hex değerleri (`#RRGGBB` veya alfa'lı `#RRGGBBAA`), palet → mod → token. */
export const PALETTES: Readonly<Record<PaletteName, Readonly<Record<ThemeName, ColorSet>>>> = {
  coffee: {
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
  },
  mono: {
    light: {
      background: '#FFFFFF',
      surface: '#FAFAFA',
      'surface-elevated': '#FFFFFF',
      fill: '#EFEFEF',
      'control-thumb': '#0A0A0A',
      'switch-thumb-off': '#737373',
      label: '#0A0A0A',
      'secondary-label': '#5C5C5C',
      'tertiary-label': '#7A7A7A',
      separator: '#E3E3E3',
      'separator-strong': '#8A8A8A',
      accent: '#0A0A0A',
      'accent-contrast': '#FFFFFF',
      'accent-ink': '#0A0A0A',
      'accent-subtle': '#EDEDED',
      success: '#2F6B45',
      'success-contrast': '#FFFFFF',
      warning: '#0A0A0A',
      danger: '#B3261E',
      'danger-subtle': '#F9E3E0',
      scrim: '#0A0A0A66',
    },
    dark: {
      background: '#050505',
      surface: '#0D0D0D',
      'surface-elevated': '#151515',
      fill: '#1F1F1F',
      'control-thumb': '#F5F5F5',
      'switch-thumb-off': '#8A8A8A',
      label: '#F5F5F5',
      'secondary-label': '#A0A0A0',
      'tertiary-label': '#707070',
      separator: '#262626',
      'separator-strong': '#6B6B6B',
      accent: '#F5F5F5',
      'accent-contrast': '#0A0A0A',
      'accent-ink': '#F5F5F5',
      'accent-subtle': '#262626',
      success: '#93CDA5',
      'success-contrast': '#0A1A0F',
      warning: '#F5F5F5',
      danger: '#FF7A6B',
      'danger-subtle': '#2C1613',
      scrim: '#000000B3',
    },
  },
  strawberry: {
    light: {
      background: '#FBF2F3',
      surface: '#FEF8F8',
      'surface-elevated': '#FFFCFC',
      fill: '#F2E1E4',
      'control-thumb': '#22161A',
      'switch-thumb-off': '#7E6E73',
      label: '#22161A',
      'secondary-label': '#64555A',
      'tertiary-label': '#85747A',
      separator: '#EAD7DB',
      'separator-strong': '#96858B',
      accent: '#D1335F',
      'accent-contrast': '#FFFFFF',
      'accent-ink': '#B42357',
      'accent-subtle': '#F9DCE5',
      success: '#2D6A43',
      'success-contrast': '#FFFFFF',
      warning: '#B42357',
      danger: '#B53A12',
      'danger-subtle': '#F8E2D8',
      scrim: '#22161A66',
    },
    dark: {
      background: '#120C0E',
      surface: '#181013',
      'surface-elevated': '#1F161A',
      fill: '#2A1F23',
      'control-thumb': '#F3EAEC',
      'switch-thumb-off': '#93868A',
      label: '#F3EAEC',
      'secondary-label': '#A6989C',
      'tertiary-label': '#7A6D71',
      separator: '#30252A',
      'separator-strong': '#75676C',
      accent: '#FF6F96',
      'accent-contrast': '#2A0611',
      'accent-ink': '#FF7FA1',
      'accent-subtle': '#341821',
      success: '#8FD3A6',
      'success-contrast': '#0B1A10',
      warning: '#FF7FA1',
      danger: '#FF8F5E',
      'danger-subtle': '#2E1A10',
      scrim: '#000000B3',
    },
  },
  matcha: {
    light: {
      background: '#F1F4EA',
      surface: '#F8FAF3',
      'surface-elevated': '#FCFDF9',
      fill: '#E1E7D5',
      'control-thumb': '#171C14',
      'switch-thumb-off': '#6E7566',
      label: '#171C14',
      'secondary-label': '#545C4E',
      'tertiary-label': '#737B6B',
      separator: '#D4DCC7',
      'separator-strong': '#848C7B',
      accent: '#9CC25A',
      'accent-contrast': '#141C06',
      'accent-ink': '#4A6E12',
      'accent-subtle': '#E1EDC8',
      success: '#1F6480',
      'success-contrast': '#FFFFFF',
      warning: '#4A6E12',
      danger: '#B3261E',
      'danger-subtle': '#F6E1DC',
      scrim: '#171C1466',
    },
    dark: {
      background: '#0C100B',
      surface: '#111610',
      'surface-elevated': '#171C16',
      fill: '#1F261D',
      'control-thumb': '#EAEFE2',
      'switch-thumb-off': '#858C7D',
      label: '#EAEFE2',
      'secondary-label': '#979F8E',
      'tertiary-label': '#6C7364',
      separator: '#263024',
      'separator-strong': '#677060',
      accent: '#B4D677',
      'accent-contrast': '#141C06',
      'accent-ink': '#B4D677',
      'accent-subtle': '#222C16',
      success: '#7CC8E3',
      'success-contrast': '#06161D',
      warning: '#B4D677',
      danger: '#FF7A6B',
      'danger-subtle': '#2C1613',
      scrim: '#000000B3',
    },
  },
  blueberry: {
    light: {
      background: '#F1F4F9',
      surface: '#F7F9FC',
      'surface-elevated': '#FCFDFF',
      fill: '#E0E6EF',
      'control-thumb': '#141A24',
      'switch-thumb-off': '#6C7480',
      label: '#141A24',
      'secondary-label': '#525B68',
      'tertiary-label': '#717A87',
      separator: '#D3DBE6',
      'separator-strong': '#828B98',
      accent: '#2F6FE0',
      'accent-contrast': '#FFFFFF',
      'accent-ink': '#1F5CC7',
      'accent-subtle': '#DCE7FA',
      success: '#2D6A43',
      'success-contrast': '#FFFFFF',
      warning: '#1F5CC7',
      danger: '#B3261E',
      'danger-subtle': '#F7E1DC',
      scrim: '#141A2466',
    },
    dark: {
      background: '#0A0E14',
      surface: '#0F141B',
      'surface-elevated': '#151B23',
      fill: '#1C2330',
      'control-thumb': '#E8EDF4',
      'switch-thumb-off': '#848C98',
      label: '#E8EDF4',
      'secondary-label': '#949DAA',
      'tertiary-label': '#69717D',
      separator: '#232B37',
      'separator-strong': '#646D7A',
      accent: '#7DB1FF',
      'accent-contrast': '#06142B',
      'accent-ink': '#7DB1FF',
      'accent-subtle': '#16243A',
      success: '#8FD3A6',
      'success-contrast': '#0B1A10',
      warning: '#7DB1FF',
      danger: '#FF7A6B',
      'danger-subtle': '#2C1613',
      scrim: '#000000B3',
    },
  },
  lemonade: {
    light: {
      background: '#F8F6E6',
      surface: '#FCFBF1',
      'surface-elevated': '#FFFEF8',
      fill: '#ECE8D0',
      'control-thumb': '#1C1A0E',
      'switch-thumb-off': '#767260',
      label: '#1C1A0E',
      'secondary-label': '#5C5947',
      'tertiary-label': '#7B7763',
      separator: '#E0DBBF',
      'separator-strong': '#8C8772',
      accent: '#F5D33D',
      'accent-contrast': '#1C1700',
      'accent-ink': '#785F00',
      'accent-subtle': '#F6EBB3',
      success: '#2D6A43',
      'success-contrast': '#FFFFFF',
      warning: '#785F00',
      danger: '#B3261E',
      'danger-subtle': '#F7E1DC',
      scrim: '#1C1A0E66',
    },
    dark: {
      background: '#0F0E08',
      surface: '#15140D',
      'surface-elevated': '#1B1A12',
      fill: '#24231A',
      'control-thumb': '#EFEDDF',
      'switch-thumb-off': '#8B8878',
      label: '#EFEDDF',
      'secondary-label': '#9C998A',
      'tertiary-label': '#716E60',
      separator: '#2B2A1F',
      'separator-strong': '#6C695A',
      accent: '#F7DA4F',
      'accent-contrast': '#1C1700',
      'accent-ink': '#F7DA4F',
      'accent-subtle': '#2C2812',
      success: '#8FD3A6',
      'success-contrast': '#0B1A10',
      warning: '#F7DA4F',
      danger: '#FF7A6B',
      'danger-subtle': '#2C1613',
      scrim: '#000000B3',
    },
  },
}

/** Varsayılan paletin (Kahve) renkleri — geriye dönük uyumluluk. */
export const COLORS: Readonly<Record<ThemeName, ColorSet>> = PALETTES[DEFAULT_PALETTE]

export function isPaletteName(value: unknown): value is PaletteName {
  return typeof value === 'string' && (PALETTE_NAMES as readonly string[]).includes(value)
}

/** SwiftUI Asset Catalog renk adları (PascalCase). */
export function swiftUIColorName(token: ColorToken): string {
  return pascalCase(token)
}

/**
 * Paletli Asset Catalog adı: her palet bir klasör (namespace), her renk Any/Dark görünümlü bir
 * renk seti — `Color("Strawberry/Accent")`.
 */
export function swiftUIPaletteColorName(palette: PaletteName, token: ColorToken): string {
  return `${pascalCase(palette)}/${pascalCase(token)}`
}

function pascalCase(value: string): string {
  return value
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
