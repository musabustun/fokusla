import { ListRow } from '@/ui'
import type { Book, TestResult, UUID } from '@/domain'
import { computeNet } from '@/domain/calc/tests'
import { formatNetValue } from './format'
import { resultSubtitle, resultTitle } from './labels'

export interface ResultRowsProps {
  results: readonly TestResult[]
  booksById: ReadonlyMap<UUID, Book>
  onSelect: (result: TestResult) => void
}

/** Test sonuçları, en yeni üstte; satıra dokunmak düzenleme sayfasını açar. */
export function ResultRows({ results, booksById, onSelect }: ResultRowsProps) {
  const sorted = results.toSorted((a, b) => b.takenAt.localeCompare(a.takenAt))
  return sorted.map((result) => (
    <ListRow
      key={result.id}
      title={resultTitle(result, booksById)}
      subtitle={resultSubtitle(result)}
      value={<span className="numeric text-label">{formatNetValue(computeNet(result))}</span>}
      onClick={() => onSelect(result)}
    />
  ))
}
