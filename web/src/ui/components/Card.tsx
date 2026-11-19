import { useId, type HTMLAttributes, type ReactNode } from 'react'
import { cx } from '../cx'

export interface CardProps extends HTMLAttributes<HTMLElement> {
  /** Verilirse bölüm etiketi (`<h2 class="eyebrow">`) gösterilir ve bölüm `<section>` olur. */
  title?: string
  /** Başlığın sağındaki küçük eylem/değer alanı. */
  trailing?: ReactNode
  children: ReactNode
}

/**
 * Çizgili bölüm: kutu yok, üstte 1px `separator` çizgisi + küçük mono bölüm etiketi. "Gece
 * mesaisi"nde yüzeyler kartla değil çizgiyle ayrılır. SwiftUI: `VStack` + üstte `Divider()`.
 */
export function Card({ title, trailing, className, children, ...rest }: CardProps) {
  const headingId = useId()
  const Element = title ? 'section' : 'div'
  return (
    <Element
      aria-labelledby={title ? headingId : undefined}
      className={cx('border-t border-separator pt-3 pb-2', className)}
      {...rest}
    >
      {title && (
        <div className="mb-4 flex min-h-11 items-center justify-between gap-3">
          <h2 id={headingId} className="eyebrow">
            {title}
          </h2>
          {trailing}
        </div>
      )}
      {children}
    </Element>
  )
}
