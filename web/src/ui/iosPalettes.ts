/**
 * iOS'a aktarılan palet verisi (`npm run export:ios-palettes`). Saf fonksiyon; sıra kararlıdır.
 * Swift: `FokusPalette` raw value'ları = `order`, `displayName` = `labels`, Asset Catalog klasörü =
 * `swiftUIPaletteColorName()` öneki (PascalCase).
 */
import {
  COLOR_TOKENS,
  DEFAULT_PALETTE,
  PALETTE_LABELS,
  PALETTE_NAMES,
  PALETTES,
  type ColorToken,
  type PaletteName,
  type ThemeName,
} from './tokens'

export interface IosPalettesJson {
  default: PaletteName
  order: PaletteName[]
  labels: Record<PaletteName, string>
  tokens: ColorToken[]
  palettes: Record<PaletteName, Record<ThemeName, Record<ColorToken, string>>>
}

interface TokenSource {
  COLOR_TOKENS: typeof COLOR_TOKENS
  DEFAULT_PALETTE: typeof DEFAULT_PALETTE
  PALETTE_LABELS: typeof PALETTE_LABELS
  PALETTE_NAMES: typeof PALETTE_NAMES
  PALETTES: typeof PALETTES
}

const THEMES: readonly ThemeName[] = ['light', 'dark']

export function toIosPalettesJson(
  source: TokenSource = {
    COLOR_TOKENS,
    DEFAULT_PALETTE,
    PALETTE_LABELS,
    PALETTE_NAMES,
    PALETTES,
  },
): IosPalettesJson {
  const pick = (palette: PaletteName, theme: ThemeName): Record<ColorToken, string> =>
    Object.fromEntries(
      source.COLOR_TOKENS.map((token) => [token, source.PALETTES[palette][theme][token]]),
    ) as Record<ColorToken, string>
  return {
    default: source.DEFAULT_PALETTE,
    order: [...source.PALETTE_NAMES],
    labels: Object.fromEntries(
      source.PALETTE_NAMES.map((name) => [name, source.PALETTE_LABELS[name]]),
    ) as Record<PaletteName, string>,
    tokens: [...source.COLOR_TOKENS],
    palettes: Object.fromEntries(
      source.PALETTE_NAMES.map((name) => [
        name,
        Object.fromEntries(THEMES.map((theme) => [theme, pick(name, theme)])),
      ]),
    ) as IosPalettesJson['palettes'],
  }
}
