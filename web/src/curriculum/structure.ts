/**
 * ÖSYM'nin cevap kâğıdındaki TEST yapısı (2026-YKS Kılavuzu, Tablo 1A ve 1B).
 *
 * Katalogdaki dersler öğrencinin takip ettiği birimlerdir; bazıları ÖSYM'de tek bir testin
 * parçasıdır (ör. Temel Matematik Testi = `tyt-matematik` + `tyt-geometri`). Bu tablo hangi
 * dersin hangi teste ait olduğunu ve testin resmî soru sayısını tutar. Net hesabı ve
 * sınav simülasyonu gibi özellikler test düzeyinde bu tabloyu kullanabilir.
 */
import type { ExamType } from '@/domain'

export interface ExamTest {
  /** Stabil anahtar, ör. `tyt-temel-matematik`. */
  key: string
  /** ÖSYM'deki resmî test adı. */
  name: string
  exam: ExamType
  /** Resmî soru sayısı. */
  questionCount: number
  /** Bu teste ait katalog ders anahtarları (kitapçık sırasıyla). */
  subjectKeys: string[]
}

export const YKS_TESTS: readonly ExamTest[] = [
  {
    key: 'tyt-turkce',
    name: 'Türkçe Testi',
    exam: 'TYT',
    questionCount: 40,
    subjectKeys: ['tyt-turkce'],
  },
  {
    key: 'tyt-sosyal-bilimler',
    name: 'Sosyal Bilimler Testi',
    exam: 'TYT',
    questionCount: 20,
    subjectKeys: ['tyt-tarih', 'tyt-cografya', 'tyt-felsefe', 'tyt-din'],
  },
  {
    key: 'tyt-temel-matematik',
    name: 'Temel Matematik Testi',
    exam: 'TYT',
    questionCount: 40,
    subjectKeys: ['tyt-matematik', 'tyt-geometri'],
  },
  {
    key: 'tyt-fen-bilimleri',
    name: 'Fen Bilimleri Testi',
    exam: 'TYT',
    questionCount: 20,
    subjectKeys: ['tyt-fizik', 'tyt-kimya', 'tyt-biyoloji'],
  },
  {
    key: 'ayt-tde-sosyal-1',
    name: 'Türk Dili ve Edebiyatı-Sosyal Bilimler-1 Testi',
    exam: 'AYT',
    questionCount: 40,
    subjectKeys: ['ayt-edebiyat', 'ayt-tarih-1', 'ayt-cografya-1'],
  },
  {
    key: 'ayt-sosyal-2',
    name: 'Sosyal Bilimler-2 Testi',
    exam: 'AYT',
    questionCount: 40,
    subjectKeys: ['ayt-tarih-2', 'ayt-cografya-2', 'ayt-felsefe-grubu', 'ayt-din'],
  },
  {
    key: 'ayt-matematik',
    name: 'Matematik Testi',
    exam: 'AYT',
    questionCount: 40,
    subjectKeys: ['ayt-matematik', 'ayt-geometri'],
  },
  {
    key: 'ayt-fen-bilimleri',
    name: 'Fen Bilimleri Testi',
    exam: 'AYT',
    questionCount: 40,
    subjectKeys: ['ayt-fizik', 'ayt-kimya', 'ayt-biyoloji'],
  },
  {
    key: 'ydt-yabanci-dil',
    name: 'Yabancı Dil Testi',
    exam: 'YDT',
    questionCount: 80,
    subjectKeys: ['ydt-yabanci-dil'],
  },
]

/** Oturum başına toplam soru sayısı (Kılavuz Tablo 1B). */
export const EXAM_QUESTION_TOTALS: Readonly<Record<ExamType, number>> = {
  TYT: 120,
  AYT: 160,
  YDT: 80,
}
