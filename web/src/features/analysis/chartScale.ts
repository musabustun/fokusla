/** NetTrendChart ölçek hesapları (saf). viewBox 0–100 birimdir. */
export const PLOT = 100
/** Uçlardaki noktalar kırpılmasın diye iç boşluk (birim). */
export const PAD_X = 4
export const PAD_Y = 8

export interface Domain {
  min: number
  max: number
}

/** Y ekseni her zaman 0'ı içerir (net negatif olabilir). Hepsi 0 ise 0–1. */
export function netDomain(nets: readonly number[]): Domain {
  const min = Math.min(0, ...nets)
  const max = Math.max(0, ...nets)
  return min === max ? { min, max: min + 1 } : { min, max }
}

export function scaleX(index: number, count: number): number {
  if (count <= 1) return PLOT / 2
  return PAD_X + (index / (count - 1)) * (PLOT - 2 * PAD_X)
}

export function scaleY(value: number, domain: Domain): number {
  const ratio = (value - domain.min) / (domain.max - domain.min)
  return PLOT - PAD_Y - ratio * (PLOT - 2 * PAD_Y)
}
