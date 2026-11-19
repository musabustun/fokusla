import { useId, type ReactNode } from 'react'
import { cx } from '../cx'

export interface ListSectionProps {
  /** Bölüm etiketi (küçük mono, büyük harf); `<h2>` olarak render edilir ve listeyi etiketler. */
  header?: string
  /** Bölümün altındaki açıklama metni. */
  footer?: ReactNode
  /** `ListRow` öğeleri (her biri bir `<li>`). */
  children: ReactNode
  className?: string
}

/**
 * Çizgili liste bölümü: kutu yok; üstte ve altta 1px çizgi, satırlar arasında ince ayraç.
 * SwiftUI: `List { Section(header:footer:) }.listStyle(.plain)` + `.listRowSeparatorTint`.
 */
export function ListSection({ header, footer, children, className }: ListSectionProps) {
  const headingId = useId()
  return (
    <section aria-labelledby={header ? headingId : undefined} className={cx('mb-10', className)}>
      {header && (
        <h2 id={headingId} className="mb-2 eyebrow">
          {header}
        </h2>
      )}
      <ul role="list" className="border-y border-separator">
        {children}
      </ul>
      {footer && <div className="mt-2 text-footnote text-secondary-label">{footer}</div>}
    </section>
  )
}
