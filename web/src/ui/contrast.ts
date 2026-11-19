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

function labComponent(t: number): number {
  return t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116
}

/** sRGB hex → CIELAB (D65). */
export function toLab(hex: string): [number, number, number] {
  const [r, g, b] = parseHex(hex).map(linearize) as [number, number, number]
  const x = labComponent((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047)
  const y = labComponent(0.2126 * r + 0.7152 * g + 0.0722 * b)
  const z = labComponent((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883)
  return [116 * y - 16, 500 * (x - y), 200 * (y - z)]
}

/** İki renk arasındaki algısal fark (CIE76 ΔE). ~2.3 fark edilebilir, ≥30 belirgin farklı renk. */
export function colorDistance(a: string, b: string): number {
  const [l1, a1, b1] = toLab(a)
  const [l2, a2, b2] = toLab(b)
  return Math.hypot(l1 - l2, a1 - a2, b1 - b2)
}
