/** Bugün ekranındaki sayı ve süre biçimleri (tr-TR). Girdi süreleri milisaniyedir; aşağı yuvarlanır. */

const MS_PER_SECOND = 1000
const SECONDS_PER_MINUTE = 60
const SECONDS_PER_HOUR = 3600

const integerFormat = new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 0 })
const decimalFormat = new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 2 })
const percentFormat = new Intl.NumberFormat('tr-TR', { style: 'percent', maximumFractionDigits: 0 })

function toWholeSeconds(ms: number): number {
  if (!Number.isFinite(ms) || ms <= 0) return 0
  return Math.floor(ms / MS_PER_SECOND)
}

function pad2(value: number): string {
  return String(value).padStart(2, '0')
}

/** Kronometre: "05:09", 1 saatten itibaren "1:05:09". */
export function formatClock(ms: number): string {
  const totalSeconds = toWholeSeconds(ms)
  const hours = Math.floor(totalSeconds / SECONDS_PER_HOUR)
  const minutes = Math.floor((totalSeconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
  const seconds = totalSeconds % SECONDS_PER_MINUTE
  const minutesAndSeconds = `${pad2(minutes)}:${pad2(seconds)}`
  return hours > 0 ? `${hours}:${minutesAndSeconds}` : minutesAndSeconds
}

/** Metin süre: "0 dk", "25 dk", "1 sa", "1 sa 5 dk" (dakika altı "0 dk"). */
export function formatDuration(ms: number): string {
  const totalMinutes = Math.floor(toWholeSeconds(ms) / SECONDS_PER_MINUTE)
  const hours = Math.floor(totalMinutes / SECONDS_PER_MINUTE)
  const minutes = totalMinutes % SECONDS_PER_MINUTE
  if (hours === 0) return `${minutes} dk`
  return minutes === 0 ? `${hours} sa` : `${hours} sa ${minutes} dk`
}

/** Süreyi saat + dakika parçalarına böler (aşağı yuvarlar); `formatDuration` ile aynı kural. */
export function splitDuration(ms: number): { hours: number; minutes: number } {
  const totalMinutes = Math.floor(toWholeSeconds(ms) / SECONDS_PER_MINUTE)
  return {
    hours: Math.floor(totalMinutes / SECONDS_PER_MINUTE),
    minutes: totalMinutes % SECONDS_PER_MINUTE,
  }
}

/** Tam sayı: "1.250". */
export function formatInteger(value: number): string {
  return integerFormat.format(value)
}

/** Net: en fazla iki ondalık, "12,75"; "-0" gösterilmez. */
export function formatNet(value: number): string {
  return decimalFormat.format(Object.is(value, -0) ? 0 : value)
}

/** Oran (0–1): "%42". */
export function formatPercent(ratio: number): string {
  return percentFormat.format(Number.isFinite(ratio) ? ratio : 0)
}
