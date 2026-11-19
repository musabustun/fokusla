/**
 * WCAG 2.x göreli parlaklık ve kontrast oranı — saf fonksiyonlar.
 * https://www.w3.org/TR/WCAG22/#dfn-relative-luminance
 */

const HEX_PATTERN = /^#([0-9a-f]{6})([0-9a-f]{2})?$/i

/** `#RRGGBB` (veya alfa'yı yok sayarak `#RRGGBBAA`) → [r, g, b] (0–255). */
export function parseHex(hex: string): [number, number, number] {
  const match = HEX_PATTERN.exec(hex)
  const digits = match?.[1]
  if (!digits) {
    throw new Error(`Geçersiz hex renk: ${hex}`)
  }
  const channel = (offset: number) => parseInt(digits.slice(offset, offset + 2), 16)
  return [channel(0), channel(2), channel(4)]
}

function linearize(channel: number): number {
  const srgb = channel / 255
  return srgb <= 0.04045 ? srgb / 12.92 : ((srgb + 0.055) / 1.055) ** 2.4
}

export function relativeLuminance(hex: string): number {
  const [r, g, b] = parseHex(hex).map(linearize) as [number, number, number]
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

/** 1 ile 21 arasında kontrast oranı (sıra önemsizdir). */
export function contrastRatio(foreground: string, background: string): number {
  const a = relativeLuminance(foreground)
  const b = relativeLuminance(background)
  const lighter = Math.max(a, b)
  const darker = Math.min(a, b)
  return (lighter + 0.05) / (darker + 0.05)
}
