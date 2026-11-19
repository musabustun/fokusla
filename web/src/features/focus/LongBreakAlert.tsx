import { AlarmClock } from 'lucide-react'
import { useId } from 'react'
import { LONG_BREAK_THRESHOLD_MS } from '@/domain/calc/focus'
import { Button } from '@/ui'
import { formatDurationText } from './formatDuration'

export interface LongBreakAlertProps {
  onResume: () => void
  onFinish: () => void
}

/** Mola eşiği aştığında gösterilir. Oturum kendiliğinden bitmez; karar kullanıcıdadır. */
export function LongBreakAlert({ onResume, onFinish }: LongBreakAlertProps) {
  const headingId = useId()
  return (
    <div role="alert" aria-labelledby={headingId} className="border-y border-separator py-5">
      <div className="flex items-start gap-3">
        <AlarmClock aria-hidden className="mt-0.5 size-5 shrink-0 text-warning" />
        <div className="min-w-0 flex-1">
          <h2 id={headingId} className="text-headline">
            Molan uzadı
          </h2>
          <p className="mt-1 text-subheadline text-secondary-label">
            Mola süren {formatDurationText(LONG_BREAK_THRESHOLD_MS)} sınırını geçti. Hazırsan odağa
            dön ya da oturumu bitir.
          </p>
        </div>
      </div>
      <div className="mt-4 flex flex-col gap-3">
        <Button size="large" fullWidth onClick={onResume}>
          Devam et
        </Button>
        <Button variant="tinted" size="large" fullWidth onClick={onFinish}>
          Oturumu bitir
        </Button>
      </div>
    </div>
  )
}
