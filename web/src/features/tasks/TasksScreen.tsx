import { ListChecks } from 'lucide-react'
import { EmptyState, ScreenHeader } from '@/ui'

// Placeholder ekran — Görevler modülü ayrı bir oturumda gerçeklenecek.
export function TasksScreen() {
  return (
    <>
      <ScreenHeader title="Görevler" subtitle="Rutinler ve ödevler" />
      <EmptyState
        icon={<ListChecks />}
        title="Görev listen boş"
        message="Her gün tekrarlanan rutinlerini ve son tarihli ödevlerini buradan planla; tamamladıkça işaretle."
      />
    </>
  )
}
