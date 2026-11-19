import { Card, Metric } from '@/ui'
import type { TestSummary } from '@/domain/calc/tests'
import { formatCount, formatDateTime, formatNet, formatPercent } from './format'

export interface SummaryCardProps {
  title: string
  summary: TestSummary
  /** true ise "Son çözülen: …" satırı gösterilir. */
  showLastTaken?: boolean
}

/** Test özeti: net ana rakam (büyük mono); başarı, test ve soru sayısı yardımcı rakamlar. */
export function SummaryCard({ title, summary, showLastTaken = false }: SummaryCardProps) {
  const lastTaken = summary.lastTakenAt
    ? `Son çözülen: ${formatDateTime(summary.lastTakenAt)}`
    : 'Henüz test yok'

  return (
    <Card title={title}>
      <Metric label="Net" value={formatNet(summary.net)} size="xl" tone="accent" />
      <div className="mt-6 grid grid-cols-3 gap-px bg-separator">
        <Metric
          label="Başarı"
          value={formatPercent(summary.accuracy)}
          size="md"
          className="bg-background pt-4 pr-3"
        />
        <Metric
          label="Toplam test"
          value={formatCount(summary.testCount)}
          size="md"
          className="bg-background px-3 pt-4"
        />
        <Metric
          label="Soru"
          value={formatCount(summary.totalQuestions)}
          size="md"
          className="bg-background pt-4 pl-3"
        />
      </div>
      {showLastTaken && <p className="mt-4 text-footnote text-secondary-label">{lastTaken}</p>}
    </Card>
  )
}
