/** İlerleme değerini 0–1 aralığına sınırlar; NaN/Infinity → 0. */
export function clampProgress(value: number): number {
  if (!Number.isFinite(value)) return 0
  return Math.min(1, Math.max(0, value))
}
