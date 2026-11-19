import { Coffee, Play, Timer } from 'lucide-react'
import { Link } from 'react-router'
import { ROUTES } from '@/app/routes'
import { useNow } from '@/data'
import type { ISODate } from '@/domain'
import {
  activeFocusState,
  focusRingProgress,
  recentFocusTotals,
  todayFocusSummary,
  type ActiveFocusState,
  type TodayFocusSummary,
} from '@/domain/calc/today'
import { buttonStyles, cx, ProgressRing } from '@/ui'
import { formatClock, formatDuration, formatInteger, splitDuration } from './format'
import { MiniWeekChart } from './MiniWeekChart'
import { TodayCard } from './TodayCard'
import { useTodayFocusData } from './useTodayData'

export interface FocusCardProps {
  today: ISODate
  className?: string
}

/** Açık oturumda canlı sayaç saniyede bir; yoksa dakikada bir yenileme yeter. */
const LIVE_REFRESH_MS = 1000
const IDLE_REFRESH_MS = 60_000

/** Yüklenirken ya da değer yokken gösterilen yer tutucu. */
const PLACEHOLDER = '—'

const EMPTY: never[] = []

/** Halka çapı (px): iPhone 390px'e sığar, iPad'de de aynı kalır (ProgressRing çapı sayıdır). */
const RING_SIZE = 256

const RING_LABELS = {
  sessionLap: 'Oturumun saatlik turu',
  weekBest: 'Bugün, son 7 günün en iyi gününe göre',
} as const

interface StatItem {
  label: string
  /** Görünen değer. */
  value: string
  /** Ekran okuyucu değeri (görünenden farklıysa, ör. "—" yerine metin). */
  spokenValue?: string
  /** true: yalnızca ekran okuyucuya okunur (değer ekranda başka yerde büyük gösterilir). */
  srOnly?: boolean
}

function buildStats(summary: TodayFocusSummary | undefined): StatItem[] {
  const average = summary && summary.averageFocusMs > 0 ? summary.averageFocusMs : null
  return [
    {
      label: 'Bugün toplam',
      value: summary ? formatDuration(summary.totalMs) : PLACEHOLDER,
      srOnly: true,
    },
    {
      label: 'Oturum sayısı',
      value: summary ? formatInteger(summary.sessionCount) : PLACEHOLDER,
    },
    {
      label: 'Ortalama kesintisiz odak',
      value: average === null ? PLACEHOLDER : formatDuration(average),
      spokenValue: average === null ? 'henüz yok' : undefined,
    },
  ]
}

/** Özet listesi; her öğe ekran okuyucuya "etiket: değer" olarak okunur. */
function StatsRow({ stats, isLoading }: { stats: StatItem[]; isLoading: boolean }) {
  return (
    <ul
      role="list"
      aria-label="Bugünün odak özeti"
      aria-busy={isLoading || undefined}
      className="grid grid-cols-2 gap-x-6 gap-y-4"
    >
      {stats.map((stat) => (
        <li
          key={stat.label}
          className={cx('flex min-w-0 flex-col gap-1.5', stat.srOnly && 'sr-only')}
        >
          {!stat.srOnly && (
            <>
              <span aria-hidden className="eyebrow">
                {stat.label}
              </span>
              <span aria-hidden className="numeric text-numeral whitespace-nowrap text-label">
                {stat.value}
              </span>
            </>
          )}
          <span className="sr-only">{`${stat.label}: ${stat.spokenValue ?? stat.value}`}</span>
        </li>
      ))}
    </ul>
  )
}

/** "1 sa 5 dk" metni: rakamlar büyük mono, birimler küçük ve ikincil; metin içeriği `formatDuration` ile aynıdır. */
function HeroDuration({ ms }: { ms: number | undefined }) {
  if (ms === undefined) return <>{PLACEHOLDER}</>
  const { hours, minutes } = splitDuration(ms)
  return (
    <>
      {hours > 0 && (
        <>
          {hours}
          <span className="font-sans text-subheadline tracking-normal text-secondary-label">
            {' '}
            sa
          </span>{' '}
        </>
      )}
      {(hours === 0 || minutes > 0) && (
        <>
          {minutes}
          <span className="font-sans text-subheadline tracking-normal text-secondary-label">
            {' '}
            dk
          </span>
        </>
      )}
    </>
  )
}

/** Açık oturumun durumu ve canlı odak süresi (halkanın altında, çizgili satır). */
function ActiveSessionPanel({ state }: { state: ActiveFocusState }) {
  const isBreak = state.phase === 'break'
  const Icon = isBreak ? Coffee : Timer
  return (
    <div className="flex w-full items-center justify-between gap-3 border-y border-separator py-3">
      <p
        className={cx(
          'flex items-center gap-2 text-subheadline font-semibold',
          isBreak ? 'text-success' : 'text-accent-ink',
        )}
      >
        <Icon aria-hidden className="size-5 shrink-0" />
        {isBreak ? 'Moladasın' : 'Odaktasın'}
      </p>
      <p role="timer" aria-label="Oturum süresi" className="numeric text-numeral text-label">
        {formatClock(state.sessionFocusMs)}
      </p>
    </div>
  )
}

/** Ekranın tek birincil eylemi: açık oturum varsa "Devam et", yoksa "Odak başlat" (kehribar hap). */
function PrimaryAction({ isActive }: { isActive: boolean }) {
  const className = buttonStyles({ variant: 'filled', size: 'large', fullWidth: true })
  if (isActive) {
    return (
      <Link to={ROUTES.focus} className={className}>
        Devam et
      </Link>
    )
  }
  return (
    <Link to={ROUTES.focus} className={className}>
      <Play aria-hidden className="size-5" />
      Odak başlat
    </Link>
  )
}

/**
 * Bugün ekranının Odak bölümü: halka içinde bugünün toplamı (ana öğe), açık oturumun canlı süresi,
 * özet rakamlar, son 7 gün ve tek dokunuşla Odak ekranına geçiş. Yalnızca okur.
 */
export function FocusCard({ today, className }: FocusCardProps) {
  const data = useTodayFocusData(today)
  const now = useNow(data?.activeSession ? LIVE_REFRESH_MS : IDLE_REFRESH_MS)

  const sessions = data?.sessions ?? EMPTY
  const segments = data?.segments ?? EMPTY
  const summary = data ? todayFocusSummary(sessions, segments, today, now) : undefined
  const active = data ? activeFocusState(data.activeSession, segments, now) : null
  const totals = recentFocusTotals(sessions, segments, today, now)
  const isLoading = data === undefined
  const showHint = !isLoading && active === null && summary?.totalMs === 0
  const ring = focusRingProgress(summary?.totalMs ?? 0, totals, active?.sessionFocusMs ?? null)

  return (
    <TodayCard title="Odak" linkTo={ROUTES.focus} linkLabel="Odak ekranı" className={className}>
      <div className="grid gap-10 lg:grid-cols-2 lg:items-center lg:gap-x-16">
        <div className="flex min-w-0 flex-col items-center gap-6">
          <ProgressRing
            value={ring.value}
            size={RING_SIZE}
            label={RING_LABELS[ring.kind]}
            tone={active?.phase === 'break' ? 'success' : 'accent'}
          >
            <div aria-hidden className="flex flex-col items-center gap-2">
              <span className="eyebrow">Bugün</span>
              <span
                data-testid="today-focus-total"
                className="numeric text-numeral-xl whitespace-nowrap text-label"
              >
                <HeroDuration ms={summary?.totalMs} />
              </span>
            </div>
          </ProgressRing>
          {active && <ActiveSessionPanel state={active} />}
          <div className="flex w-full max-w-sm flex-col items-center gap-3">
            {showHint && (
              <p className="text-center text-callout text-secondary-label">
                Bugün henüz odaklanmadın — 25 dakikayla başla.
              </p>
            )}
            {isLoading ? (
              <div aria-hidden className="h-13 w-full rounded-full bg-fill" />
            ) : (
              <PrimaryAction isActive={active !== null} />
            )}
          </div>
        </div>
        <div className="flex min-w-0 flex-col gap-8">
          <StatsRow stats={buildStats(summary)} isLoading={isLoading} />
          <MiniWeekChart totals={totals} today={today} />
        </div>
      </div>
    </TodayCard>
  )
}
