import type { ReactNode } from 'react'
import { cx } from '../cx'

export interface EmptyStateProps {
  /** Dekoratif ikon (lucide-react); ince çizgili bir dairede gösterilir. */
  icon?: ReactNode
  title: string
  message?: ReactNode
  /** Ör. `<Button>` veya `buttonStyles()` ile biçimlenmiş bir `<Link>`. */
  action?: ReactNode
  className?: string
}

/** Boş/henüz hazır olmayan içerik (SwiftUI: `ContentUnavailableView`). */
export function EmptyState({ icon, title, message, action, className }: EmptyStateProps) {
  return (
    <div
      className={cx(
        'mx-auto flex max-w-md flex-col items-center px-6 py-12 text-center text-balance',
        className,
      )}
    >
      {icon && (
        <div
          aria-hidden
          className="mb-5 flex size-16 items-center justify-center rounded-full border border-separator text-secondary-label [&_svg]:size-7 [&_svg]:stroke-[1.5]"
        >
          {icon}
        </div>
      )}
      <h2 className="text-title3">{title}</h2>
      {message && <p className="mt-2 text-callout text-secondary-label">{message}</p>}
      {action && <div className="mt-6">{action}</div>}
    </div>
  )
}
