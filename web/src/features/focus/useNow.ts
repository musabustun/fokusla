import { useEffect, useState } from 'react'

const DEFAULT_INTERVAL_MS = 1000

/**
 * `intervalMs` aralıklarla yeniden render tetikleyen güncel zaman. Yalnızca "şimdi"yi verir;
 * süreler her zaman zaman damgalarından yeniden hesaplanır, burada birikmez.
 */
export function useNow(intervalMs: number = DEFAULT_INTERVAL_MS): Date {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), intervalMs)
    return () => clearInterval(id)
  }, [intervalMs])
  return now
}
