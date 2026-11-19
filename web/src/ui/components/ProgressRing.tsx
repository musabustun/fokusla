import type { ReactNode } from 'react'
import { cx } from '../cx'
import { clampProgress } from './clampProgress'

export interface ProgressRingProps {
  /** 0–1 arası ilerleme; dışındaki değerler (ve NaN) sınırlanır. */
  value: number
  /** Piksel cinsinden çap. Varsayılan 120. */
  size?: number
  /** Halka kalınlığı (px). Varsayılan 10. */
  strokeWidth?: number
  /**
   * Erişilebilir ad (ör. "Günlük odak hedefi"). Verilirse `role="progressbar"`; verilmezse
   * halka dekoratif kabul edilir (`aria-hidden`) ve değer metin olarak başka yerde verilmelidir.
   */
  label?: string
  /** Ortadaki içerik (ör. "45 dk"). */
  children?: ReactNode
  tone?: 'accent' | 'success'
  className?: string
}

/** SVG ilerleme halkası (SwiftUI: `Circle().trim(from: 0, to: value)`). */
export function ProgressRing({
  value,
  size = 120,
  strokeWidth = 10,
  label,
  children,
  tone = 'accent',
  className,
}: ProgressRingProps) {
  const progress = clampProgress(value)
  const radius = (size - strokeWidth) / 2
  const circumference = 2 * Math.PI * radius
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
      className={cx('relative inline-flex shrink-0 items-center justify-center', className)}
      style={{ width: size, height: size }}
    >
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="-rotate-90">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          strokeWidth={strokeWidth}
          className="stroke-fill"
        />
        {progress > 0 && (
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            strokeWidth={strokeWidth}
            strokeLinecap="round"
            strokeDasharray={circumference}
            strokeDashoffset={circumference * (1 - progress)}
            className={cx(
              'motion-safe:transition-[stroke-dashoffset] motion-safe:duration-500',
              tone === 'success' ? 'stroke-success' : 'stroke-accent',
            )}
          />
        )}
      </svg>
      {children && (
        <div className="absolute inset-0 flex items-center justify-center">{children}</div>
      )}
    </div>
  )
}
