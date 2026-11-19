import type { ReactNode } from 'react'
import { Link } from 'react-router'
import { buttonStyles, Card, cx } from '@/ui'

export interface TodayCardProps {
  /** Kart başlığı (`<h2>`); kart bu adla bir `region` olur. */
  title: string
  /** Sağ üstteki "Tümü" bağlantısının hedefi (`ROUTES.*`). Verilmezse bağlantı yok. */
  linkTo?: string
  /** Erişilebilir adın devamı, ör. "Tüm görevler" → "Tümü: Tüm görevler". Görünür metin "Tümü". */
  linkLabel?: string
  className?: string
  children: ReactNode
}

/**
 * Bugün ekranındaki her kartın ortak kabuğu: başlık + "Tümü" bağlantısı + içerik.
 * SwiftUI: `Section(header:)` içinde `NavigationLink("Tümü")`.
 */
export function TodayCard({ title, linkTo, linkLabel, className, children }: TodayCardProps) {
  const trailing = linkTo ? (
    <Link
      to={linkTo}
      // Görünür metin ("Tümü") erişilebilir adın başında olmalı (WCAG 2.5.3).
      aria-label={`Tümü: ${linkLabel ?? title}`}
      className={cx(buttonStyles({ variant: 'plain', size: 'small' }), '-my-2 -mr-2')}
    >
      Tümü
    </Link>
  ) : undefined
  return (
    <Card title={title} trailing={trailing} className={cx('flex flex-col', className)}>
      {children}
    </Card>
  )
}

export interface CardEmptyProps {
  /** Tek cümlelik açıklama, ör. "Henüz test yok". */
  message: string
  /** Tek sonraki adımın etiketi, ör. "İlk testini ekle". */
  actionLabel: string
  /** Eylemin hedefi (`ROUTES.*`). */
  to: string
}

/** Kartın boş durumu: kısa açıklama + tek bir sonraki adım bağlantısı. */
export function CardEmpty({ message, actionLabel, to }: CardEmptyProps) {
  return (
    <div className="flex flex-1 flex-col items-start gap-3">
      <p className="text-callout text-secondary-label">{message}</p>
      <Link to={to} className={buttonStyles({ variant: 'tinted', size: 'small' })}>
        {actionLabel}
      </Link>
    </div>
  )
}
