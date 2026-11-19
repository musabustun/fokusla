import { Card } from '@/ui'
import { dailyNetTrend } from '@/domain/calc/tests'
import type { TestResult } from '@/domain'
import { NetTrendChart } from './NetTrendChart'

export interface TrendCardProps {
  results: readonly TestResult[]
}

export const TREND_TITLE = 'Net trendi'

/** Günlük net trendi kartı; sonuç yoksa hiçbir şey göstermez. */
export function TrendCard({ results }: TrendCardProps) {
  if (results.length === 0) return null
  const points = dailyNetTrend(results)
  return (
    <Card title={TREND_TITLE}>
      <NetTrendChart points={points} label={TREND_TITLE} />
      {points.length === 1 && (
        <p className="mt-2 text-footnote text-secondary-label">
          Trend çizgisi için en az iki farklı günde test çöz.
        </p>
      )}
    </Card>
  )
}
