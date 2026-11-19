import { useId, type HTMLAttributes, type ReactNode } from 'react'
import { cx } from '../cx'

export interface CardProps extends HTMLAttributes<HTMLElement> {
  /** Verilirse `<h2>` başlık olarak gösterilir ve kart `<section>` olarak etiketlenir. */
  title?: string
  /** Başlığın sağındaki küçük eylem/değer alanı. */
  trailing?: ReactNode
  children: ReactNode
}

export function Card({ title, trailing, className, children, ...rest }: CardProps) {
  const headingId = useId()
  const Element = title ? 'section' : 'div'
  return (
    <Element
      aria-labelledby={title ? headingId : undefined}
      className={cx('rounded-lg bg-surface p-4', className)}
      {...rest}
    >
      {title && (
        <div className="mb-3 flex items-center justify-between gap-3">
          <h2 id={headingId} className="text-headline">
            {title}
          </h2>
          {trailing}
        </div>
      )}
      {children}
    </Element>
  )
}
