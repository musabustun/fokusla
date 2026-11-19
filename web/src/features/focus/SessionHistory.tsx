import { ListRow, ListSection } from '@/ui'
import { formatDurationText } from './formatDuration'
import type { HistoryRow } from './history'

export interface SessionHistoryProps {
  rows: readonly HistoryRow[]
}

/** Son bitmiş oturumlar listesi (en yeni önce). */
export function SessionHistory({ rows }: SessionHistoryProps) {
  return (
    <ListSection header="Geçmiş oturumlar">
      {rows.length === 0 ? (
        <ListRow title="Henüz tamamlanmış oturum yok" />
      ) : (
        rows.map((row) => (
          <ListRow
            key={row.id}
            title={row.title}
            subtitle={row.subtitle}
            value={formatDurationText(row.focusMs)}
          />
        ))
      )}
    </ListSection>
  )
}
