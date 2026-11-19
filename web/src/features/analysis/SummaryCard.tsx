import { Card } from '@/ui'
import type { TestSummary } from '@/domain/calc/tests'
import { formatCount, formatDateTime, formatNet, formatPercent } from './format'

export interface SummaryCardProps {
  title: string
  summary: TestSummary
  /** true ise "Son çözülen: …" satırı gösterilir. */
  showLastTaken?: boolean
}

interface Stat {
  label: string
  value: string
}

function statsOf(summary: TestSummary): Stat[] {
  return [
    { label: 'Toplam test', value: formatCount(summary.testCount) },
    { label: 'Soru', value: formatCount(summary.totalQuestions) },
    { label: 'Net', value: formatNet(summary.net) },
    { label: 'Başarı', value: formatPercent(summary.accuracy) },
  ]
}

/** Test özetinin dört temel sayısı (toplam test, soru, net, başarı). */
export function SummaryCard({ title, summary, showLastTaken = false }: SummaryCardProps) {
  const lastTaken = summary.lastTakenAt
    ? `Son çözülen: ${formatDateTime(summary.lastTakenAt)}`
    : 'Henüz test yok'

  return (
    <Card title={title} className="@container">
      <dl className="grid grid-cols-2 gap-x-4 gap-y-3 @sm:grid-cols-4">
        {statsOf(summary).map((stat) => (
          <div key={stat.label} className="flex flex-col-reverse">
            <dt className="text-footnote text-secondary-label">{stat.label}</dt>
            <dd className="text-title2 tabular-nums">{stat.value}</dd>
          </div>
        ))}
      </dl>
      {showLastTaken && (
        <p className="mt-3 border-t border-separator pt-3 text-footnote text-secondary-label">
          {lastTaken}
        </p>
      )}
    </Card>
  )
}
