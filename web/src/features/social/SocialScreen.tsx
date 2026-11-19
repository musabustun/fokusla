import { Users } from 'lucide-react'
import { EmptyState, ScreenHeader } from '@/ui'

// Placeholder ekran — Sosyal modülü ayrı bir oturumda gerçeklenecek.
export function SocialScreen() {
  return (
    <>
      <ScreenHeader title="Sosyal" subtitle="Birlikte çalış" />
      <EmptyState
        icon={<Users />}
        title="Arkadaşların yakında burada"
        message="Arkadaş ekle ve paralel odak odalarında aynı anda çalışın; kimin odakta olduğunu canlı gör."
      />
    </>
  )
}
