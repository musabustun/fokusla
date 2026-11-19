import type { ReactNode } from 'react'
import { cx } from '../cx'

export type MetricSize = 'hero' | 'xl' | 'lg' | 'md' | 'sm'
export type MetricTone = 'default' | 'accent' | 'success'

export interface MetricProps {
  /** Küçük mono bölüm etiketi (ör. "Bugün", "Ortalama mola"). */
  label: ReactNode
  /** Büyük rakam (ör. "2:45", "38,5"). Mono + tabular. */
  value: ReactNode
  /** Rakamın yanındaki küçük birim (ör. "sa", "dk", "net"). */
  unit?: ReactNode
  /** Altındaki ikincil açıklama. */
  caption?: ReactNode
  /** `hero` 72px · `xl` 56px · `lg` 36px · `md` 24px · `sm` 17px. Varsayılan `lg`. */
  size?: MetricSize
  /** `accent` yalnızca ekranın ana sayısı için (tek kehribar vurgu). */
  tone?: MetricTone
  /**
   * Değer rakam mı? Varsayılan `true` (mono + tabular). Tarih/metin değerleri ("19 Kasım",
   * "Yeterli veri yok") için `false`: Bricolage, bir kademe küçük.
   */
  numeric?: boolean
  className?: string
}

const VALUE_SIZES: Record<MetricSize, string> = {
  hero: 'text-numeral-hero',
  xl: 'text-numeral-xl',
  lg: 'text-numeral-lg',
  md: 'text-numeral',
  sm: 'text-numeral-sm',
}

const TEXT_SIZES: Record<MetricSize, string> = {
  hero: 'text-title1',
  xl: 'text-title1',
  lg: 'text-title2',
  md: 'text-title3',
  sm: 'text-headline',
}

const TONES: Record<MetricTone, string> = {
  default: 'text-label',
  accent: 'text-accent-ink',
  success: 'text-success',
}

/**
 * Büyük, iddialı rakam + küçük etiket: ekranların ana öğesi. Etiket önce okunur (ekran okuyucu
 * sırası "Bugün, 2:45 sa"). SwiftUI: `VStack(alignment: .leading) { Text(label).eyebrow(); Text(value).numeral() }`.
 */
export function Metric({
  label,
  value,
  unit,
  caption,
  size = 'lg',
  tone = 'default',
  numeric = true,
  className,
}: MetricProps) {
  return (
    <div className={cx('flex min-w-0 flex-col gap-1.5', className)}>
      <span className="eyebrow">{label}</span>
      <span
        className={cx(
          'flex items-baseline gap-1.5',
          numeric ? cx('numeric', VALUE_SIZES[size]) : cx('font-display', TEXT_SIZES[size]),
          TONES[tone],
        )}
      >
        <span className="min-w-0 truncate">{value}</span>
        {unit && (
          <span className="font-sans text-subheadline tracking-normal text-secondary-label">
            {/* Baştaki boşluk görünmez (flex öğesi) ama metin "35 dk" olarak okunur. */} {unit}
          </span>
        )}
      </span>
      {caption && <span className="text-footnote text-secondary-label">{caption}</span>}
    </div>
  )
}
