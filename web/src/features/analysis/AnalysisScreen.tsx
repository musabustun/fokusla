import { ChartColumn } from 'lucide-react'
import { EmptyState, ScreenHeader } from '@/ui'

// Placeholder ekran — Analiz modülü ayrı bir oturumda gerçeklenecek.
export function AnalysisScreen() {
  return (
    <>
      <ScreenHeader title="Analiz" subtitle="Deneme ve test sonuçların" />
      <EmptyState
        icon={<ChartColumn />}
        title="Henüz test kaydın yok"
        message="Çözdüğün testleri ders → konu ve kitap bazında kaydet: doğru, yanlış ve boş sayılarını gir; netin (D − Y/4) otomatik hesaplanıp gelişimin burada görünecek."
      />
    </>
  )
}
