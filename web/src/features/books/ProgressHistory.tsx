/** Kitabın ilerleme geçmişi (en yeni önce); her kayıt silinebilir. */
import { Trash2 } from 'lucide-react'
import type { BookProgress, BookUnit } from '@/domain'
import { ListRow, ListSection } from '@/ui'
import { formatDay, formatPosition } from './bookLabels'

export interface ProgressHistoryProps {
  /** `useBookHistory()` sonucu; yüklenirken undefined. */
  entries: readonly BookProgress[] | undefined
  unit: BookUnit
  now: Date
  onDelete: (entry: BookProgress) => void
}

function subtitleOf(entry: BookProgress, now: Date): string {
  const day = formatDay(new Date(entry.recordedAt), now)
  return entry.note ? `${day} · ${entry.note}` : day
}

export function ProgressHistory({ entries, unit, now, onDelete }: ProgressHistoryProps) {
  if (entries === undefined) return null
  if (entries.length === 0) {
    return (
      <ListSection header="Geçmiş">
        <ListRow title={<span className="text-secondary-label">Henüz ilerleme girmedin.</span>} />
      </ListSection>
    )
  }
  return (
    <ListSection header="Geçmiş">
      {entries.map((entry) => {
        const position = formatPosition(unit, entry.reachedUnit)
        return (
          <ListRow
            key={entry.id}
            title={position}
            subtitle={subtitleOf(entry, now)}
            accessory={
              <button
                type="button"
                aria-label={`${position} kaydını sil`}
                onClick={() => onDelete(entry)}
                className="-mr-2 flex size-11 items-center justify-center rounded-full text-danger transition-colors active:bg-fill"
              >
                <Trash2 aria-hidden className="size-5" />
              </button>
            }
          />
        )
      })}
    </ListSection>
  )
}
