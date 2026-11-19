/**
 * Test sonucu formu — SAF yardımcılar (React/Dexie yok). Form alanları ham metin tutar;
 * doğrulama bunları TestResult girdisine dönüştürür ve Türkçe hata mesajları üretir.
 */
import { toISODate, type ISODate, type ISODateTime, type TestResult, type UUID } from '@/domain'

/** "Kaynak kitap" seçicisinde serbest metin kaynağı ("Diğer (yaz)") temsil eden değer. */
export const OTHER_SOURCE = 'other'

/** Serbest metin alanlarının azami uzunluğu. */
export const MAX_TEXT_LENGTH = 80

export interface TestResultFormValues {
  subjectId: string
  /** '' = konu seçilmedi. */
  topicId: string
  /** '' = kitap yok, `OTHER_SOURCE` = serbest metin kaynak, aksi halde Book id. */
  bookId: string
  sourceName: string
  label: string
  questionCount: string
  correct: string
  wrong: string
  blank: string
  blankAuto: boolean
  /** YYYY-MM-DD (yerel gün). */
  date: string
}

export type TestResultFormErrors = Partial<Record<keyof TestResultFormValues, string>>

export interface TestResultFormInput {
  subjectId: UUID
  topicId: UUID | null
  bookId: UUID | null
  sourceName: string | null
  label: string | null
  correct: number
  wrong: number
  blank: number
  date: ISODate
}

export type TestResultFormValidation =
  { ok: true; input: TestResultFormInput } | { ok: false; errors: TestResultFormErrors }

export interface TestResultFormDefaults {
  subjectId?: UUID
  topicId?: UUID | null
}

export const FORM_MESSAGES = {
  subjectRequired: 'Ders seçmelisin.',
  countInvalid: 'Negatif olmayan bir tam sayı gir.',
  questionCountInvalid: 'Soru sayısı en az 1 olan bir tam sayı olmalı.',
  sumExceeds: 'Doğru + yanlış + boş, soru sayısını aşamaz.',
  noQuestions: 'En az bir soru girmelisin.',
  dateRequired: 'Tarih seçmelisin.',
  dateInvalid: 'Geçerli bir tarih gir.',
  dateInFuture: 'Gelecekteki bir tarih seçilemez.',
  textTooLong: `En fazla ${MAX_TEXT_LENGTH} karakter olabilir.`,
} as const

/** Doğru + yanlış + boş toplamı soru sayısından azsa gösterilen mesaj. */
export function sumMismatchMessage(sum: number, questionCount: number): string {
  return `Doğru + yanlış + boş (${sum}) soru sayısına (${questionCount}) eşit olmalı.`
}

const INTEGER_PATTERN = /^\d+$/
const DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/

/** Yeni kayıt için boş form. Boş otomatik hesaplanır. */
export function emptyFormValues(
  today: ISODate,
  defaults: TestResultFormDefaults = {},
): TestResultFormValues {
  return {
    subjectId: defaults.subjectId ?? '',
    topicId: defaults.topicId ?? '',
    bookId: '',
    sourceName: '',
    label: '',
    questionCount: '',
    correct: '',
    wrong: '',
    blank: '',
    blankAuto: true,
    date: today,
  }
}

/** Düzenleme için mevcut kayıttan form. Soru sayısı = D + Y + B; tarih = takenAt'in yerel günü. */
export function formValuesFromResult(result: TestResult): TestResultFormValues {
  const sourceName = result.sourceName ?? ''
  const bookId = result.bookId ?? (sourceName ? OTHER_SOURCE : '')
  return {
    subjectId: result.subjectId,
    topicId: result.topicId ?? '',
    bookId,
    sourceName: result.bookId ? '' : sourceName,
    label: result.label ?? '',
    questionCount: String(result.correct + result.wrong + result.blank),
    correct: String(result.correct),
    wrong: String(result.wrong),
    blank: String(result.blank),
    blankAuto: false,
    date: toISODate(new Date(result.takenAt)),
  }
}

/** Boş alan 0 sayılır; geçersizse null. */
function parseCount(raw: string): number | null {
  const value = raw.trim()
  if (value === '') return 0
  return INTEGER_PATTERN.test(value) ? Number(value) : null
}

/** Boş → null (verilmedi); geçersiz → NaN. */
function parseQuestionCount(raw: string): number | null {
  const value = raw.trim()
  if (value === '') return null
  return INTEGER_PATTERN.test(value) && Number(value) >= 1 ? Number(value) : Number.NaN
}

/**
 * Otomatik boş açıksa ve soru/doğru/yanlış okunabiliyorsa boş = soru − doğru − yanlış.
 * Negatif çıkarsa olduğu gibi bırakılır; doğrulama "aşamaz" hatası verir.
 */
export function resolveBlank(values: TestResultFormValues): TestResultFormValues {
  if (!values.blankAuto) return values
  const questions = parseQuestionCount(values.questionCount)
  const correct = parseCount(values.correct)
  const wrong = parseCount(values.wrong)
  if (questions === null || Number.isNaN(questions) || correct === null || wrong === null) {
    return values
  }
  return { ...values, blank: String(questions - correct - wrong) }
}

/** Önizleme için sayılar (boş otomatik çözülmüş); biri geçersizse null. */
export function previewCounts(
  values: TestResultFormValues,
): Pick<TestResultFormInput, 'correct' | 'wrong' | 'blank'> | null {
  const resolved = resolveBlank(values)
  const correct = parseCount(resolved.correct)
  const wrong = parseCount(resolved.wrong)
  const blank = parseCount(resolved.blank)
  if (correct === null || wrong === null || blank === null) return null
  return { correct, wrong, blank }
}

function isRealDate(value: string): boolean {
  const match = DATE_PATTERN.exec(value)
  if (!match) return false
  const [, y, m, d] = match.map(Number)
  const date = new Date(y ?? 0, (m ?? 1) - 1, d ?? 0)
  return date.getFullYear() === y && date.getMonth() === (m ?? 1) - 1 && date.getDate() === d
}

function validateDate(raw: string, today: ISODate): string | undefined {
  const value = raw.trim()
  if (value === '') return FORM_MESSAGES.dateRequired
  if (!isRealDate(value)) return FORM_MESSAGES.dateInvalid
  // YYYY-MM-DD sözlük sırası takvim sırasıyla aynıdır.
  if (value > today) return FORM_MESSAGES.dateInFuture
  return undefined
}

function optionalText(raw: string): string | null {
  const value = raw.trim()
  return value === '' ? null : value
}

interface ParsedCounts {
  correct: number | null
  wrong: number | null
  blank: number | null
  questions: number | null
}

function validateCounts(values: TestResultFormValues, errors: TestResultFormErrors): ParsedCounts {
  const resolved = resolveBlank(values)
  const correct = parseCount(resolved.correct)
  const wrong = parseCount(resolved.wrong)
  const negativeAutoBlank = resolved.blankAuto && /^-\d+$/.test(resolved.blank)
  const blank = negativeAutoBlank ? null : parseCount(resolved.blank)
  const questions = parseQuestionCount(resolved.questionCount)

  if (correct === null) errors.correct = FORM_MESSAGES.countInvalid
  if (wrong === null) errors.wrong = FORM_MESSAGES.countInvalid
  if (blank === null && !negativeAutoBlank) errors.blank = FORM_MESSAGES.countInvalid
  if (questions !== null && Number.isNaN(questions)) {
    errors.questionCount = FORM_MESSAGES.questionCountInvalid
    return { correct, wrong, blank, questions }
  }
  if (correct === null || wrong === null) return { correct, wrong, blank, questions }

  if (questions !== null) {
    const sum = correct + wrong + (blank ?? 0)
    if (negativeAutoBlank || sum > questions) errors.questionCount = FORM_MESSAGES.sumExceeds
    else if (blank !== null && sum < questions) {
      errors.questionCount = sumMismatchMessage(sum, questions)
    }
  } else if (blank !== null && correct + wrong + blank === 0) {
    errors.questionCount = FORM_MESSAGES.noQuestions
  }
  return { correct, wrong, blank, questions }
}

function resolveSource(
  values: TestResultFormValues,
): Pick<TestResultFormInput, 'bookId' | 'sourceName'> {
  if (values.bookId === OTHER_SOURCE)
    return { bookId: null, sourceName: optionalText(values.sourceName) }
  return { bookId: values.bookId === '' ? null : values.bookId, sourceName: null }
}

/** Formu doğrular; geçerliyse kaydedilecek girdiyi, değilse alan bazlı Türkçe hataları döner. */
export function validateTestResultForm(
  values: TestResultFormValues,
  today: ISODate,
): TestResultFormValidation {
  const errors: TestResultFormErrors = {}
  if (values.subjectId === '') errors.subjectId = FORM_MESSAGES.subjectRequired
  const { correct, wrong, blank } = validateCounts(values, errors)
  const dateError = validateDate(values.date, today)
  if (dateError) errors.date = dateError

  const source = resolveSource(values)
  const label = optionalText(values.label)
  if (label && label.length > MAX_TEXT_LENGTH) errors.label = FORM_MESSAGES.textTooLong
  if (source.sourceName && source.sourceName.length > MAX_TEXT_LENGTH) {
    errors.sourceName = FORM_MESSAGES.textTooLong
  }

  if (Object.keys(errors).length > 0 || correct === null || wrong === null || blank === null) {
    return { ok: false, errors }
  }
  return {
    ok: true,
    input: {
      subjectId: values.subjectId,
      topicId: values.topicId === '' ? null : values.topicId,
      ...source,
      label,
      correct,
      wrong,
      blank,
      date: values.date.trim(),
    },
  }
}

/**
 * Seçilen günün kayıt zamanı: bugünse şu an, değilse o günün YEREL öğleni
 * (UTC'ye çevrilince gün kaymasın diye).
 */
export function takenAtFor(date: ISODate, now: Date): ISODateTime {
  if (toISODate(now) === date) return now.toISOString()
  const [y, m, d] = date.split('-').map(Number)
  return new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1, 12).toISOString()
}
