import { cx } from '../cx'
import { clampProgress } from './clampProgress'

export interface ProgressBarProps {
  /** 0–1 arası ilerleme; dışındaki değerler (ve NaN) sınırlanır. */
  value: number
  /**
   * Erişilebilir ad (ör. "Kitap ilerlemesi"). Verilirse `role="progressbar"`; verilmezse çubuk
   * dekoratif kabul edilir (`aria-hidden`) ve değer metin olarak başka yerde verilmelidir.
   */
  label?: string
  tone?: 'accent' | 'success'
  /** `small` = 2px (liste satırı), `medium` = 4px (detay). Varsayılan `medium`. */
  size?: 'small' | 'medium'
  className?: string
}

/** Yatay ilerleme çubuğu (SwiftUI: `ProgressView(value:).progressViewStyle(.linear)`). */
export function ProgressBar({
  value,
  label,
  tone = 'accent',
  size = 'medium',
  className,
}: ProgressBarProps) {
  const progress = clampProgress(value)
  const a11y = label
    ? {
        role: 'progressbar',
        'aria-label': label,
        'aria-valuemin': 0,
        'aria-valuemax': 100,
        'aria-valuenow': Math.round(progress * 100),
      }
    : { 'aria-hidden': true }

  return (
    <div
      {...a11y}
      className={cx(
        'w-full overflow-hidden rounded-full bg-separator',
        size === 'small' ? 'h-0.5' : 'h-1',
        className,
      )}
    >
      <div
        className={cx(
          'h-full rounded-full motion-safe:transition-[width] motion-safe:duration-700 motion-safe:ease-emphasized',
          tone === 'success' ? 'bg-success' : 'bg-accent-ink',
        )}
        style={{ width: `${progress * 100}%` }}
      />
    </div>
  )
}
