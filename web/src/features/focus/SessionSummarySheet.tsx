import type { FocusSessionStats } from '@/domain/calc/focus'
import { Button, ListRow, ListSection, Metric, Sheet } from '@/ui'
import { formatClock, formatDurationText } from './formatDuration'

export interface SessionSummarySheetProps {
  /** Gösterilecek özet; null iken sheet kapalıdır. */
  stats: FocusSessionStats | null
  onClose: () => void
}

const countFormat = new Intl.NumberFormat('tr-TR')

/** "Bitir" sonrası oturum özeti. */
export function SessionSummarySheet({ stats, onClose }: SessionSummarySheetProps) {
  return (
    <Sheet
      open={stats !== null}
      onClose={onClose}
      title="Oturum özeti"
      footer={
        <Button size="large" fullWidth onClick={onClose}>
          Tamam
        </Button>
      }
    >
      {stats && (
        <>
          <Metric
            size="xl"
            tone="accent"
            label="Bu oturumda odak"
            value={formatClock(stats.focusMs)}
            className="mb-8"
          />
          <ListSection className="mb-0">
            <ListRow
              title="Toplam odak"
              value={<span className="numeric">{formatDurationText(stats.focusMs)}</span>}
            />
            <ListRow
              title="Mola sayısı"
              value={<span className="numeric">{countFormat.format(stats.breakCount)}</span>}
            />
            <ListRow
              title="Toplam mola"
              value={<span className="numeric">{formatDurationText(stats.breakMs)}</span>}
            />
          </ListSection>
        </>
      )}
    </Sheet>
  )
}
