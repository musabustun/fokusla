import type { ISODate } from '@/domain'
import type { DailyFocusTotal } from '@/domain/calc/focus'
import { cx } from '@/ui'
import { formatDuration } from './format'

export interface MiniWeekChartProps {
  /** Eskiden yeniye günlük odak toplamları (genelde son 7 gün). */
  totals: readonly DailyFocusTotal[]
  /** Vurgulanacak gün (bugün). */
  today: ISODate
  className?: string
}

const LOCALE = 'tr-TR'
const shortWeekday = new Intl.DateTimeFormat(LOCALE, { weekday: 'short' })
const longWeekday = new Intl.DateTimeFormat(LOCALE, { weekday: 'long' })

/** Sıfır olmayan günlerde çubuk görünür kalsın diye en küçük yükseklik (%). */
const MIN_BAR_PERCENT = 6

/** `YYYY-MM-DD` → YEREL gece yarısı (UTC olarak ayrıştırılırsa gün kayabilir). */
function parseLocalDate(day: ISODate): Date {
  const [year = 0, month = 1, date = 1] = day.split('-').map(Number)
  return new Date(year, month - 1, date)
}

function barPercent(focusMs: number, maxMs: number): number {
  if (focusMs <= 0 || maxMs <= 0) return 0
  return Math.max(MIN_BAR_PERCENT, (focusMs / maxMs) * 100)
}

/**
 * Bugün kartındaki küçük 7 günlük odak grafiği. Görsel çubuklar dekoratiftir;
 * her gün ekran okuyucuya "<gün>: <süre>" olarak okunur. Bugün `aria-current="date"`.
 */
export function MiniWeekChart({ totals, today, className }: MiniWeekChartProps) {
  const maxMs = Math.max(0, ...totals.map((total) => total.focusMs))
  const weekTotalMs = totals.reduce((sum, total) => sum + total.focusMs, 0)
  return (
    <div className={cx('flex flex-col gap-2', className)}>
      <p className="flex items-baseline justify-between gap-3 text-footnote text-secondary-label">
        <span aria-hidden>Son 7 gün</span>
        <span className="tabular-nums">
          <span className="sr-only">Son 7 gün toplam: </span>
          {formatDuration(weekTotalMs)}
        </span>
      </p>
      <ul role="list" aria-label="Son 7 gün" className="flex h-20 items-stretch gap-1.5">
        {totals.map((total) => {
          const isToday = total.day === today
          const date = parseLocalDate(total.day)
          return (
            <li
              key={total.day}
              aria-current={isToday ? 'date' : undefined}
              className="flex min-w-0 flex-1 flex-col items-center gap-1"
            >
              <div aria-hidden className="flex w-full flex-1 items-end rounded-sm bg-fill">
                <div
                  className="w-full rounded-sm bg-accent motion-safe:transition-[height] motion-safe:duration-300"
                  style={{ height: `${barPercent(total.focusMs, maxMs)}%` }}
                />
              </div>
              <span
                aria-hidden
                className={cx(
                  'text-caption',
                  isToday ? 'font-semibold text-label' : 'text-secondary-label',
                )}
              >
                {shortWeekday.format(date)}
              </span>
              <span className="sr-only">
                {`${longWeekday.format(date)}: ${formatDuration(total.focusMs)}`}
              </span>
            </li>
          )
        })}
      </ul>
    </div>
  )
}
