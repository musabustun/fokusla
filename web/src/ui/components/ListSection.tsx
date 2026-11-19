import { useId, type ReactNode } from 'react'
import { cx } from '../cx'

export interface ListSectionProps {
  /** Bölüm başlığı (küçük, gri); `<h2>` olarak render edilir ve listeyi etiketler. */
  header?: string
  /** Bölümün altındaki açıklama metni. */
  footer?: ReactNode
  /** `ListRow` öğeleri (her biri bir `<li>`). */
  children: ReactNode
  className?: string
}

/** iOS "inset grouped" liste bölümü. */
export function ListSection({ header, footer, children, className }: ListSectionProps) {
  const headingId = useId()
  return (
    <section aria-labelledby={header ? headingId : undefined} className={cx('mb-8', className)}>
      {header && (
        <h2 id={headingId} className="mb-1.5 px-4 text-footnote text-secondary-label uppercase">
          {header}
        </h2>
      )}
      <ul role="list" className="overflow-hidden rounded-lg bg-surface">
        {children}
      </ul>
      {footer && <div className="mt-1.5 px-4 text-footnote text-secondary-label">{footer}</div>}
    </section>
  )
}
