import { useMemo } from 'react'
import { ROUTES } from '@/app/routes'
import type { ISODate } from '@/domain'
import { MIN_QUESTIONS_FOR_WEAKNESS, type WeakTopic } from '@/domain/calc/tests'
import { recentTestsSummary, weakestTopicsForToday } from '@/domain/calc/today'
import { CardEmpty, TodayCard } from './TodayCard'
import { formatInteger, formatNet, formatPercent } from './format'
import { useTodayTestsData, type TodayTestsData } from './useTodayData'

export interface TestsCardProps {
  today: ISODate
  className?: string
}

const TITLE = 'Son testler'
const UNKNOWN_TOPIC = 'Adsız konu'

interface Stat {
  label: string
  value: string
  /** Değerin yanındaki küçük birim, ör. "soru". */
  unit?: string
}

/** Sayılar: görünürde büyük değer + küçük etiket; ekran okuyucu "etiket: değer" okur. */
function StatList({ stats }: { stats: readonly Stat[] }) {
  return (
    <dl className="grid grid-cols-3 gap-x-3 gap-y-2">
      {stats.map((stat) => (
        <div key={stat.label} className="flex min-w-0 flex-col-reverse">
          <dt className="truncate text-footnote text-secondary-label">{stat.label}</dt>
          <dd className="truncate">
            <span className="text-title2 tabular-nums">{stat.value}</span>
            {stat.unit && (
              <>
                {' '}
                <span className="text-footnote text-secondary-label">{stat.unit}</span>
              </>
            )}
          </dd>
        </div>
      ))}
    </dl>
  )
}

function WeakTopicRow({ weak, data }: { weak: WeakTopic; data: TodayTestsData }) {
  const topicName = data.topicNames.get(weak.topicId) ?? UNKNOWN_TOPIC
  const subjectId = data.topicSubjects.get(weak.topicId)
  const subjectName = subjectId === undefined ? undefined : data.subjectNames.get(subjectId)
  return (
    <li className="flex items-center justify-between gap-3 py-2">
      <div className="min-w-0">
        <p className="truncate text-callout">{topicName}</p>
        {subjectName && (
          <p className="truncate text-footnote text-secondary-label">{subjectName}</p>
        )}
      </div>
      <p className="shrink-0 text-subheadline text-secondary-label tabular-nums">
        {formatPercent(weak.summary.accuracy)} doğru
      </p>
    </li>
  )
}

function WeakTopics({ data }: { data: TodayTestsData }) {
  const weakTopics = useMemo(() => weakestTopicsForToday(data.results), [data.results])
  return (
    <div className="mt-4 border-t border-separator pt-3">
      <h3 className="text-subheadline font-semibold">En zayıf konular</h3>
      {weakTopics.length === 0 ? (
        <p className="mt-1 text-footnote text-secondary-label">
          Zayıf konular için bir konuda en az {formatInteger(MIN_QUESTIONS_FOR_WEAKNESS)} soru çöz.
        </p>
      ) : (
        <ul className="divide-y divide-separator">
          {weakTopics.map((weak) => (
            <WeakTopicRow key={weak.topicId} weak={weak} data={data} />
          ))}
        </ul>
      )}
    </div>
  )
}

/** Son testler: bugün ve son 7 günde çözülen soru, 7 günün neti ve en zayıf 3 konu. */
export function TestsCard({ today, className }: TestsCardProps) {
  const data = useTodayTestsData()
  const summary = useMemo(
    () => (data ? recentTestsSummary(data.results, today) : undefined),
    [data, today],
  )

  if (data === undefined || summary === undefined) {
    return (
      <TodayCard title={TITLE} className={className}>
        <div aria-busy="true" className="min-h-16" />
      </TodayCard>
    )
  }

  if (summary.allTimeCount === 0) {
    return (
      <TodayCard title={TITLE} className={className}>
        <CardEmpty message="Henüz test yok." actionLabel="İlk testini ekle" to={ROUTES.analysis} />
      </TodayCard>
    )
  }

  const stats: Stat[] = [
    { label: 'Bugün', value: formatInteger(summary.todayQuestions), unit: 'soru' },
    { label: 'Son 7 gün', value: formatInteger(summary.window.totalQuestions), unit: 'soru' },
    { label: '7 günde net', value: formatNet(summary.window.net) },
  ]

  return (
    <TodayCard
      title={TITLE}
      linkTo={ROUTES.analysis}
      linkLabel="Analiz ekranı"
      className={className}
    >
      <StatList stats={stats} />
      <WeakTopics data={data} />
    </TodayCard>
  )
}
