import { ChevronRight } from 'lucide-react'
import type { ReactElement, ReactNode } from 'react'
import { cx } from '../cx'

/** `render` ile özel bir öğe (ör. react-router `<Link>`) kullanırken verilen props. */
export interface ListRowRenderProps {
  className: string
  children: ReactNode
}

export interface ListRowProps {
  title: ReactNode
  subtitle?: ReactNode
  /** Soldaki ikon (lucide-react, dekoratif). */
  icon?: ReactNode
  /** Sağdaki ikincil metin (ör. "Yakında", "0.1.0"). */
  value?: ReactNode
  /** Sağdaki özel denetim (ör. SegmentedControl, Switch). */
  accessory?: ReactNode
  /** Sağda ">" gösterilsin mi? Varsayılan: satır etkileşimliyse (onClick/href/render) true. */
  chevron?: boolean
  /** Satırı `<button type="button">` yapar. */
  onClick?: () => void
  /** Satırı düz bir `<a href>` yapar (harici/router-dışı bağlantı). */
  href?: string
  /**
   * Router bağlantısı için: `render={(props) => <Link to={ROUTES.books} {...props} />}`.
   * Verilen `className` ve `children` olduğu gibi iletilmelidir.
   */
  render?: (props: ListRowRenderProps) => ReactElement
}

const ROW = 'flex min-h-11 w-full items-center gap-3 px-4 py-2.5 text-left'
const INTERACTIVE = 'transition-colors active:bg-fill'

function RowContent({ title, subtitle, icon, value, accessory, chevron }: ListRowProps) {
  return (
    <>
      {icon && (
        <span aria-hidden className="flex size-7 shrink-0 items-center justify-center text-accent">
          {icon}
        </span>
      )}
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="text-body text-label">{title}</span>
        {subtitle && <span className="text-subheadline text-secondary-label">{subtitle}</span>}
      </span>
      {value && <span className="shrink-0 text-body text-secondary-label">{value}</span>}
      {accessory && <span className="shrink-0">{accessory}</span>}
      {chevron && (
        <ChevronRight
          aria-hidden
          className="size-5 shrink-0 text-tertiary-label"
          strokeWidth={2.5}
        />
      )}
    </>
  )
}

function RowElement(props: ListRowProps) {
  const { onClick, href, render } = props
  const isInteractive = Boolean(onClick || href || render)
  const content = <RowContent {...props} chevron={props.chevron ?? isInteractive} />
  const className = cx(ROW, isInteractive && INTERACTIVE)

  if (render) return render({ className, children: content })
  if (href) {
    return (
      <a href={href} className={className}>
        {content}
      </a>
    )
  }
  if (onClick) {
    return (
      <button type="button" onClick={onClick} className={className}>
        {content}
      </button>
    )
  }
  return <div className={className}>{content}</div>
}

/** iOS liste satırı; her zaman bir `ListSection` içinde kullanılır (`<li>` render eder). */
export function ListRow(props: ListRowProps) {
  return (
    <li
      className={cx(
        'relative',
        'before:absolute before:top-0 before:right-0 before:h-px before:bg-separator first:before:hidden',
        props.icon ? 'before:left-14' : 'before:left-4',
      )}
    >
      <RowElement {...props} />
    </li>
  )
}
