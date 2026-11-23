/**
 * Gömülü kitap kütüphanesi tipleri. Katalog saf veridir; barkodla bulunan kayıt kitap formunu
 * doldurur ve kullanıcının özel kopyasına dönüşür (bkz. docs/books-library.md).
 */
import type { BookKind, BookUnit, ExamType } from '@/domain'

export interface LibrarySection {
  title: string
  /** 1'den başlayan, kitap içinde benzersiz ve artan sıra. */
  order: number
  /** Bölümün ilk birimi (sayfa/test no). Bilinmiyorsa null. */
  startUnit: number | null
  /** Bölümün son birimi. Bilinmiyorsa null. */
  endUnit: number | null
  /** Müfredat konusu anahtarı (kitabın dersine ait olmalı). Yoksa null. */
  topicCatalogKey: string | null
}

export interface LibraryBook {
  /** Stabil, ASLA değişmeyen/silinmeyen anahtar. Biçim: `<yayinevi>-<ders>-<ad>[-<yil>]` slug'ı. */
  key: string
  /** Normalleştirilmiş EAN-13 barkodlar (bir kitabın birden çok baskısı/barkodu olabilir). */
  barcodes: string[]
  title: string
  publisher: string | null
  kind: BookKind
  exam: ExamType | null
  /** Müfredat dersi anahtarı (ör. `tyt-matematik`). Yoksa null. */
  subjectCatalogKey: string | null
  unit: BookUnit
  totalUnits: number | null
  editionYear: number | null
  sections: LibrarySection[]
}

export interface BookLibrary {
  /** Katalog sürümü; her içerik değişikliğinde artar. */
  version: number
  /** Son güncelleme tarihi (YYYY-MM-DD). */
  updatedAt: string
  books: LibraryBook[]
}
