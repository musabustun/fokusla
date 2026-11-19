import { ChevronLeft } from 'lucide-react'
import { Link } from 'react-router'
import { cx } from '@/ui'

export interface BackLinkProps {
  to: string
  /** Görünen hedef adı, ör. "Analiz" veya ders adı. Erişilebilir ad: "Geri: <label>". */
  label: string
  className?: string
}

/** iOS gezinme çubuğu tarzı geri bağlantısı (≥44px dokunma hedefi). */
export function BackLink({ to, label, className }: BackLinkProps) {
  return (
    <Link
      to={to}
      aria-label={`Geri: ${label}`}
      className={cx(
        'mb-1 -ml-2 inline-flex min-h-11 max-w-full items-center gap-0.5 rounded-full pr-3 text-body text-secondary-label transition-[background-color,transform] duration-200 ease-standard hover:bg-fill active:scale-97 motion-reduce:active:scale-100',
        className,
      )}
    >
      <ChevronLeft aria-hidden className="size-6 shrink-0" strokeWidth={2.5} />
      <span className="truncate">{label}</span>
    </Link>
  )
}
