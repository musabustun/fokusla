import { Coffee, Play, Timer } from 'lucide-react'
import { Link } from 'react-router'
import { ROUTES } from '@/app/routes'
import { useNow } from '@/data'
import type { ISODate } from '@/domain'
import {
  activeFocusState,
  recentFocusTotals,
  todayFocusSummary,
  type ActiveFocusState,
  type TodayFocusSummary,
} from '@/domain/calc/today'
import { buttonStyles } from '@/ui'
import { formatClock, formatDuration, formatInteger } from './format'
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

interface StatItem {
  label: string
  /** Görünen değer. */
  value: string
  /** Ekran okuyucu değeri (görünenden farklıysa, ör. "—" yerine metin). */
  spokenValue?: string
  testId?: string
}

function buildStats(summary: TodayFocusSummary | undefined): StatItem[] {
  const average = summary && summary.averageFocusMs > 0 ? summary.averageFocusMs : null
  return [
    {
      label: 'Bugün toplam',
      value: summary ? formatDuration(summary.totalMs) : PLACEHOLDER,
      testId: 'today-focus-total',
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

/** Üç istatistik; her biri ekran okuyucuya "etiket: değer" olarak okunur. */
function StatsRow({ stats, isLoading }: { stats: StatItem[]; isLoading: boolean }) {
  return (
    <ul
      role="list"
      aria-label="Bugünün odak özeti"
      aria-busy={isLoading || undefined}
      className="grid grid-cols-3 gap-3"
    >
      {stats.map((stat) => (
        <li key={stat.label} className="flex min-w-0 flex-col gap-0.5">
          <span
            aria-hidden
            data-testid={stat.testId}
            className="text-title3 whitespace-nowrap text-label tabular-nums"
          >
            {stat.value}
          </span>
          <span aria-hidden className="text-caption text-secondary-label">
            {stat.label}
          </span>
          <span className="sr-only">{`${stat.label}: ${stat.spokenValue ?? stat.value}`}</span>
        </li>
      ))}
    </ul>
  )
}

/** Açık oturumun durumu ve canlı odak süresi. */
function ActiveSessionPanel({ state }: { state: ActiveFocusState }) {
  const isBreak = state.phase === 'break'
  const Icon = isBreak ? Coffee : Timer
  return (
    <div className="flex items-center justify-between gap-3 rounded-md bg-accent-subtle px-4 py-3">
      <p className="flex items-center gap-2 text-subheadline font-semibold text-accent">
        <Icon aria-hidden className="size-5 shrink-0" />
        {isBreak ? 'Moladasın' : 'Odaktasın'}
      </p>
      <p role="timer" aria-label="Oturum süresi" className="text-title1 text-label tabular-nums">
        {formatClock(state.sessionFocusMs)}
      </p>
    </div>
  )
}

/** Kartın tek birincil eylemi: açık oturum varsa "Devam et", yoksa "Odak başlat". */
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
 * Bugün ekranının Odak kartı: bugünün özeti, açık oturumun canlı süresi, son 7 gün ve
 * tek dokunuşla Odak ekranına geçiş. Yalnızca okur; oturum başlatma/bitirme Odak ekranındadır.
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

  return (
    <TodayCard title="Odak" linkTo={ROUTES.focus} linkLabel="Odak ekranı" className={className}>
      <div className="grid gap-4 md:grid-cols-2 md:gap-x-8">
        <div className="flex min-w-0 flex-col gap-4">
          {active && <ActiveSessionPanel state={active} />}
          <StatsRow stats={buildStats(summary)} isLoading={isLoading} />
          <div className="flex flex-col gap-2">
            {showHint && (
              <p className="text-callout text-secondary-label">
                Bugün henüz odaklanmadın — 25 dakikayla başla.
              </p>
            )}
            {isLoading ? (
              <div aria-hidden className="h-13 rounded-lg bg-fill" />
            ) : (
              <PrimaryAction isActive={active !== null} />
            )}
          </div>
        </div>
        <MiniWeekChart totals={totals} today={today} className="md:self-end" />
      </div>
    </TodayCard>
  )
}
