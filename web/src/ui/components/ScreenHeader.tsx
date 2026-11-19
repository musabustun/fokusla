import type { ReactNode } from 'react'
import { cx } from '../cx'

export interface ScreenHeaderProps {
  /** Ekranın büyük başlığı (`<h1>`); sayfa başına bir tane. */
  title: string
  subtitle?: ReactNode
  /** Sağ üstteki eylemler (ör. plain `<Button>`). */
  actions?: ReactNode
  className?: string
}

/**
 * Büyük başlık: Bricolage 800, sıkı aralık; altında ikincil alt başlık.
 * SwiftUI: `.navigationTitle` + `.navigationBarTitleDisplayMode(.large)` (özel font ile).
 */
export function ScreenHeader({ title, subtitle, actions, className }: ScreenHeaderProps) {
  return (
    <header className={cx('mb-8 flex items-end gap-3', className)}>
      <div className="min-w-0 flex-1">
        <h1 className="text-large-title text-balance md:text-display">{title}</h1>
        {subtitle && <p className="mt-2 text-subheadline text-secondary-label">{subtitle}</p>}
      </div>
      {actions && <div className="flex shrink-0 items-center gap-1">{actions}</div>}
    </header>
  )
}
