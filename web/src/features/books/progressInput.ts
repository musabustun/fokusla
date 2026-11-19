/** İlerleme girişinin ayrıştırılması (saf). */

/** "34" → 34; boş, ondalıklı, negatif ya da sayı olmayan girdi → null. */
export function parseReachedUnit(raw: string): number | null {
  const trimmed = raw.trim()
  if (!/^\d+$/.test(trimmed)) return null
  const value = Number(trimmed)
  return Number.isSafeInteger(value) ? value : null
}
