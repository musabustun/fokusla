import { Timer } from 'lucide-react'
import { EmptyState, ScreenHeader } from '@/ui'

// Placeholder ekran — Odak modülü ayrı bir oturumda gerçeklenecek.
export function FocusScreen() {
  return (
    <>
      <ScreenHeader title="Odak" subtitle="Kronometre ve oturumlar" />
      <EmptyState
        icon={<Timer />}
        title="Odak oturumu yakında"
        message="Kronometreyle odak oturumu başlat, mola ver, devam et. Oturum süren, günlük toplamın, ortalama kesintisiz odak ve mola sürelerin burada görünecek."
      />
    </>
  )
}
