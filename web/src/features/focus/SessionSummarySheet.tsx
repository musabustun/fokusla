import type { FocusSessionStats } from '@/domain/calc/focus'
import { Button, ListRow, ListSection, Sheet } from '@/ui'
import { formatDurationText } from './formatDuration'

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
        <ListSection className="mb-0">
          <ListRow title="Toplam odak" value={formatDurationText(stats.focusMs)} />
          <ListRow title="Mola sayısı" value={countFormat.format(stats.breakCount)} />
          <ListRow title="Toplam mola" value={formatDurationText(stats.breakMs)} />
        </ListSection>
      )}
    </Sheet>
  )
}
