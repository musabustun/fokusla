import { BookOpen } from 'lucide-react'
import { EmptyState, ScreenHeader } from '@/ui'

// Placeholder ekran — Kitaplar modülü ayrı bir oturumda gerçeklenecek.
export function BooksScreen() {
  return (
    <>
      <ScreenHeader title="Kitaplar" subtitle="Soru bankaları ve kaynaklar" />
      <EmptyState
        icon={<BookOpen />}
        title="Kitaplığın boş"
        message="Kullandığın kitapları ekle ve her kitapta nereye kadar geldiğini takip et. Bitirdiğin testler ve kalan bölümler burada görünecek."
      />
    </>
  )
}
