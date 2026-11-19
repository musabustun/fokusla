import type { PresenceState } from '@/domain'
import { cx } from '@/ui'

const DOT_CLASS: Record<PresenceState, string> = {
  focusing: 'bg-success',
  onBreak: 'bg-tertiary-label',
  offline: 'border-2 border-separator-strong',
}

/** Durum noktası — dekoratif; durum her zaman metinle de verilir (yalnızca renge dayanmaz). */
export function PresenceDot({ state }: { state: PresenceState }) {
  return (
    <span
      aria-hidden
      data-state={state}
      className={cx('inline-block size-2.5 shrink-0 rounded-full', DOT_CLASS[state])}
    />
  )
}
