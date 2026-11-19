/**
 * YDT (Yabancı Dil Testi) — yalnızca DİL puan türü (DİL = %40 TYT + %60 YDT, Kılavuz Tablo 1E).
 *
 * ÖSYM YDT'yi Almanca, Arapça, Fransızca, İngilizce ve Rusça dillerinde yapar; her dil için
 * 80 soru (Kılavuz Tablo 1B). Konular dile bağlı değil, YDT'deki soru tipleridir (beceri bazlı).
 * Anahtarları (slug) ASLA değiştirme/silme.
 */
import { defineSubject } from './define'

const yabanciDil = defineSubject({
  key: 'ydt-yabanci-dil',
  name: 'Yabancı Dil (YDT)',
  exam: 'YDT',
  fields: ['DIL'],
  questionCount: 80,
  topics: [
    ['kelime-bilgisi', 'Kelime Bilgisi'],
    ['dil-bilgisi', 'Dil Bilgisi'],
    ['cloze-test', 'Cloze Test'],
    ['cumle-tamamlama', 'Cümle Tamamlama'],
    ['ceviri-yabanci-dilden-turkceye', 'Çeviri (Yabancı Dil → Türkçe)'],
    ['ceviri-turkceden-yabanci-dile', 'Çeviri (Türkçe → Yabancı Dil)'],
    ['paragraf', 'Paragraf (Okuduğunu Anlama)'],
    ['diyalog-tamamlama', 'Diyalog Tamamlama'],
    ['anlamca-en-yakin-cumle', 'Anlamca En Yakın Cümle'],
    ['paragraf-tamamlama', 'Paragraf Tamamlama'],
    ['anlam-butunlugunu-bozan-cumle', 'Paragrafta Anlam Bütünlüğünü Bozan Cümle'],
  ],
})

export const ydtSubjects = [yabanciDil]
