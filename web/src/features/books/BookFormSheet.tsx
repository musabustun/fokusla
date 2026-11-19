// GEÇİCİ İSKELET — liste ajanı tarafından gerçeklenecek. Props SÖZLEŞMESİ sabittir.
import type { Book, Subject } from '@/domain'
import { Sheet } from '@/ui'

export interface BookFormSheetProps {
  open: boolean
  onClose: () => void
  /** Verilirse düzenleme modu ("Kitabı düzenle"); yoksa ekleme ("Kitap ekle"). */
  book?: Book
  /** Ders seçicisi için (useBooksData().subjects). */
  subjects: readonly Subject[]
  /** Kayıt başarılı olunca (oluşturulan/güncellenen kitapla) çağrılır; ardından onClose. */
  onSaved?: (book: Book) => void
}

export function BookFormSheet({ open, onClose, book }: BookFormSheetProps) {
  return (
    <Sheet open={open} onClose={onClose} title={book ? 'Kitabı düzenle' : 'Kitap ekle'}>
      {null}
    </Sheet>
  )
}
