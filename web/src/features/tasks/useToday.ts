import { useEffect, useState } from 'react'
import { toISODate, type ISODate } from '@/domain'

/** Bir sonraki yerel gece yarısına (+1 sn pay) kalan milisaniye. */
export function msUntilNextMidnight(now: Date): number {
  const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 1)
  return Math.max(0, next.getTime() - now.getTime())
}

/**
 * Bugünün YEREL günü (`YYYY-MM-DD`). Gece yarısında ve sekme yeniden görünür olduğunda
 * (uyku/arka plan sonrası) güncellenir.
 */
export function useToday(): ISODate {
  const [today, setToday] = useState(() => toISODate(new Date()))

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined

    const refresh = () => {
      setToday(toISODate(new Date()))
      schedule()
    }
    function schedule() {
      clearTimeout(timer)
      timer = setTimeout(refresh, msUntilNextMidnight(new Date()))
    }
    const handleVisibility = () => {
      if (document.visibilityState === 'visible') refresh()
    }

    schedule()
    document.addEventListener('visibilitychange', handleVisibility)
    return () => {
      clearTimeout(timer)
      document.removeEventListener('visibilitychange', handleVisibility)
    }
  }, [])

  return today
}
