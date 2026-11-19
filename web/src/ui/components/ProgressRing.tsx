import type { ReactNode } from 'react'
import { cx } from '../cx'
import { clampProgress } from './clampProgress'

export interface ProgressRingProps {
  /** 0–1 arası ilerleme; dışındaki değerler (ve NaN) sınırlanır. */
  value: number
  /** Piksel cinsinden çap. Varsayılan 120. */
  size?: number
  /** Halka kalınlığı (px). Varsayılan 6 — ince yay, büyük rakam. */
  strokeWidth?: number
  /**
   * Erişilebilir ad (ör. "Günlük odak hedefi"). Verilirse `role="progressbar"`; verilmezse
   * halka (SVG) dekoratif kabul edilir ve değer metin olarak verilmelidir. `children` her iki
   * durumda da erişilebilir kalır (ör. ortadaki `role="timer"` saat).
   */
  label?: string
  /** Ortadaki içerik (ör. "45 dk"). */
  children?: ReactNode
  tone?: 'accent' | 'success'
  /**
   * true ise çap `className` ile verilir (ör. `w-64 xl:w-80`) ve halka genişliğe göre ölçeklenir;
   * `size` yalnızca çizim ölçeğidir (kalınlık onunla orantılı büyür). SwiftUI: `.frame(width:)`
   * yerine `.aspectRatio(1, contentMode: .fit)`.
   */
  fluid?: boolean
  className?: string
}

/**
 * İnce SVG ilerleme halkası: iz `separator`, yay `accent-ink` (koyu temada kehribar, açıkta AA
 * uyumlu koyu kehribar) veya `success`. Değer değişince yay 700ms akar (hareket azaltmada anında).
 * SwiftUI: `Circle().trim(from: 0, to: value).stroke(style: .init(lineCap: .round))`.
 */
export function ProgressRing({
  value,
  size = 120,
  strokeWidth = 6,
  label,
  children,
  tone = 'accent',
  fluid = false,
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
    : {}

  return (
    <div
      {...a11y}
      className={cx(
        'relative inline-flex shrink-0 items-center justify-center',
        fluid && 'aspect-square',
        className,
      )}
      style={fluid ? undefined : { width: size, height: size }}
    >
      <svg
        aria-hidden
        width={fluid ? '100%' : size}
        height={fluid ? '100%' : size}
        viewBox={`0 0 ${size} ${size}`}
        className="-rotate-90"
      >
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          strokeWidth={strokeWidth}
          className="stroke-separator"
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
              'motion-safe:transition-[stroke-dashoffset] motion-safe:duration-700 motion-safe:ease-emphasized',
              tone === 'success' ? 'stroke-success' : 'stroke-accent-ink',
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
