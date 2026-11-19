/**
 * YKS müfredat kataloğu.
 *
 * - Test yapısı ve soru sayıları: ÖSYM 2026-YKS Kılavuzu (Tablo 1A, 1B, 1E) — doğrulandı.
 * - Konu listeleri: ÖSYM'nin dayandığı MEB "Ortak Derslere Ait Kazanım ve Açıklamalar"
 *   belgesindeki ünitelerden ve yaygın "YKS konuları" listelerinden TÜRETİLMİŞTİR. Resmî bir
 *   ÖSYM konu listesi değildir; düzenlenebilir bir başlangıç noktasıdır (bkz. README.md).
 * - 2027-YKS Kılavuzu yayımlandığında (genellikle Şubat) soru sayılarını yeniden doğrula,
 *   `examYear`, `sources` ve `verifiedAt` alanlarını güncelle.
 *
 * Ders verisi `data/` klasöründedir: tyt.ts, ayt.ts, ydt.ts.
 */
import { aytSubjects } from './data/ayt'
import { tytSubjects } from './data/tyt'
import { ydtSubjects } from './data/ydt'
import type { Curriculum } from './types'

export const yksCurriculum: Curriculum = {
  examYear: 2026,
  sources: [
    'ÖSYM 2026-YKS Kılavuzu (Tablo 1A, 1B, 1C, 1D, 1E; bölüm 3.1 ve 3.10): https://dokuman.osym.gov.tr/pdfdokuman/2026/YKS/basvuru_kilavuz06022026.pdf',
    'ÖSYM 2026-YKS Kılavuzu duyuru sayfası: https://www.osym.gov.tr/2026yuksekogretim-kurumlari-sinavi-yks-kilavuzu',
    'MEB, (ÖSYM tarafından 2026 yılında gerçekleştirilecek TYT, AYT ve YDT sınavlarına esas) Ortak Derslere Ait Kazanım ve Açıklamalar: https://ttkb.meb.gov.tr/meb_iys_dosyalar/2025_11/26164023_2026_yks.pdf',
    'Konu adları ve sıralaması: MEB ünite başlıkları + yaygın kullanılan "YKS konuları" listeleri (türetilmiş, düzenlenebilir)',
  ],
  verifiedAt: '2026-11-19',
  subjects: [...tytSubjects, ...aytSubjects, ...ydtSubjects],
}
