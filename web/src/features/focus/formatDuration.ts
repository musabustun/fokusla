/** Odak ekranındaki süre biçimleri. Girdi milisaniyedir; değerler aşağı yuvarlanır (floor). */

const MS_PER_SECOND = 1000
const SECONDS_PER_MINUTE = 60
const SECONDS_PER_HOUR = 3600

function toWholeSeconds(ms: number): number {
  if (!Number.isFinite(ms) || ms <= 0) return 0
  return Math.floor(ms / MS_PER_SECOND)
}

function pad2(value: number): string {
  return String(value).padStart(2, '0')
}

/** Kronometre görünümü: "05:09", 1 saatten itibaren "1:05:09". */
export function formatClock(ms: number): string {
  const totalSeconds = toWholeSeconds(ms)
  const hours = Math.floor(totalSeconds / SECONDS_PER_HOUR)
  const minutes = Math.floor((totalSeconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
  const seconds = totalSeconds % SECONDS_PER_MINUTE
  const minutesAndSeconds = `${pad2(minutes)}:${pad2(seconds)}`
  return hours > 0 ? `${hours}:${minutesAndSeconds}` : minutesAndSeconds
}

/** Metin olarak süre: "45 sn", "25 dk", "1 sa", "1 sa 5 dk". 1 dakikadan itibaren saniye düşer. */
export function formatDurationText(ms: number): string {
  const totalSeconds = toWholeSeconds(ms)
  if (totalSeconds < SECONDS_PER_MINUTE) return `${totalSeconds} sn`
  const totalMinutes = Math.floor(totalSeconds / SECONDS_PER_MINUTE)
  const hours = Math.floor(totalMinutes / SECONDS_PER_MINUTE)
  const minutes = totalMinutes % SECONDS_PER_MINUTE
  if (hours === 0) return `${minutes} dk`
  return minutes === 0 ? `${hours} sa` : `${hours} sa ${minutes} dk`
}
