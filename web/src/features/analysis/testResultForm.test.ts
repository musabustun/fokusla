import { describe, expect, it } from 'vitest'
import { toISODate, type TestResult } from '@/domain'
import {
  emptyFormValues,
  FORM_MESSAGES,
  formValuesFromResult,
  MAX_TEXT_LENGTH,
  OTHER_SOURCE,
  previewCounts,
  resolveBlank,
  sumMismatchMessage,
  takenAtFor,
  validateTestResultForm,
  type TestResultFormValues,
} from './testResultForm'

const TODAY = '2026-11-19'
const SUBJECT = '11111111-1111-4111-8111-111111111111'
const TOPIC = '22222222-2222-4222-8222-222222222222'
const BOOK = '33333333-3333-4333-8333-333333333333'

function values(overrides: Partial<TestResultFormValues> = {}): TestResultFormValues {
  return { ...emptyFormValues(TODAY, { subjectId: SUBJECT }), ...overrides }
}

function result(overrides: Partial<TestResult> = {}): TestResult {
  return {
    id: '44444444-4444-4444-8444-444444444444',
    createdAt: '2026-11-10T09:00:00.000Z',
    updatedAt: '2026-11-10T09:00:00.000Z',
    deletedAt: null,
    subjectId: SUBJECT,
    topicId: TOPIC,
    bookId: null,
    sourceName: null,
    label: 'Test 12',
    takenAt: new Date(2026, 10, 10, 15).toISOString(),
    correct: 10,
    wrong: 4,
    blank: 6,
    durationSeconds: null,
    note: null,
    ...overrides,
  }
}

describe('emptyFormValues', () => {
  it('varsayılanlarla boş form üretir', () => {
    expect(emptyFormValues(TODAY)).toEqual({
      subjectId: '',
      topicId: '',
      bookId: '',
      sourceName: '',
      label: '',
      questionCount: '',
      correct: '',
      wrong: '',
      blank: '',
      blankAuto: true,
      date: TODAY,
    })
  })

  it('ders ve konu varsayılanlarını alır; null konu boş olur', () => {
    expect(emptyFormValues(TODAY, { subjectId: SUBJECT, topicId: TOPIC })).toMatchObject({
      subjectId: SUBJECT,
      topicId: TOPIC,
    })
    expect(emptyFormValues(TODAY, { subjectId: SUBJECT, topicId: null }).topicId).toBe('')
  })
})

describe('formValuesFromResult', () => {
  it.each([
    {
      name: 'kitapsız, kaynaksız',
      input: result(),
      expected: { bookId: '', sourceName: '', topicId: TOPIC, label: 'Test 12' },
    },
    {
      name: 'kayıtlı kitap',
      input: result({ bookId: BOOK, sourceName: null }),
      expected: { bookId: BOOK, sourceName: '' },
    },
    {
      name: 'serbest kaynak',
      input: result({ sourceName: 'Okul fasikülü' }),
      expected: { bookId: OTHER_SOURCE, sourceName: 'Okul fasikülü' },
    },
    {
      name: 'sourceName alanı olmayan eski kayıt',
      input: (() => {
        const { sourceName: _omit, ...rest } = result({ topicId: null, label: null })
        return rest as TestResult
      })(),
      expected: { bookId: '', sourceName: '', topicId: '', label: '' },
    },
  ])('$name', ({ input, expected }) => {
    expect(formValuesFromResult(input)).toMatchObject(expected)
  })

  it('soru sayısını D+Y+B, tarihi yerel gün olarak doldurur; otomatik boş kapalı', () => {
    expect(formValuesFromResult(result())).toMatchObject({
      subjectId: SUBJECT,
      questionCount: '20',
      correct: '10',
      wrong: '4',
      blank: '6',
      blankAuto: false,
      date: '2026-11-10',
    })
  })
})

describe('resolveBlank', () => {
  it.each([
    { q: '20', c: '12', w: '3', b: '', auto: true, expected: '5' },
    { q: '20', c: '', w: '', b: '', auto: true, expected: '20' },
    { q: '10', c: '8', w: '5', b: '', auto: true, expected: '-3' },
    { q: '', c: '8', w: '5', b: '', auto: true, expected: '' },
    { q: 'x', c: '8', w: '5', b: '1', auto: true, expected: '1' },
    { q: '0', c: '0', w: '0', b: '1', auto: true, expected: '1' },
    { q: '20', c: '1.5', w: '5', b: '', auto: true, expected: '' },
    { q: '20', c: '12', w: '3', b: '1', auto: false, expected: '1' },
  ])('q=$q c=$c w=$w auto=$auto → boş "$expected"', ({ q, c, w, b, auto, expected }) => {
    const input = values({ questionCount: q, correct: c, wrong: w, blank: b, blankAuto: auto })
    expect(resolveBlank(input).blank).toBe(expected)
  })

  it('girdiyi değiştirmez', () => {
    const input = values({ questionCount: '10', correct: '5' })
    const copy = { ...input }
    resolveBlank(input)
    expect(input).toEqual(copy)
  })
})

describe('previewCounts', () => {
  it.each([
    {
      v: { questionCount: '20', correct: '12', wrong: '4' },
      expected: { correct: 12, wrong: 4, blank: 4 },
    },
    { v: {}, expected: { correct: 0, wrong: 0, blank: 0 } },
    { v: { correct: '-1' }, expected: null },
    { v: { questionCount: '5', correct: '4', wrong: '4' }, expected: null },
  ])('$v → $expected', ({ v, expected }) => {
    expect(previewCounts(values(v))).toEqual(expected)
  })
})

describe('validateTestResultForm — geçerli', () => {
  it('otomatik boşu hesaplar, metinleri kırpar, kitap yoksa kaynak null', () => {
    const validation = validateTestResultForm(
      values({
        topicId: TOPIC,
        label: '  Test 12 ',
        questionCount: '20',
        correct: '12',
        wrong: '4',
      }),
      TODAY,
    )
    expect(validation).toEqual({
      ok: true,
      input: {
        subjectId: SUBJECT,
        topicId: TOPIC,
        bookId: null,
        sourceName: null,
        label: 'Test 12',
        correct: 12,
        wrong: 4,
        blank: 4,
        date: TODAY,
      },
    })
  })

  it.each([
    {
      name: 'serbest kaynak',
      v: { bookId: OTHER_SOURCE, sourceName: '  Okul fasikülü ', correct: '1' },
      expected: { bookId: null, sourceName: 'Okul fasikülü' },
    },
    {
      name: 'boş serbest kaynak → null',
      v: { bookId: OTHER_SOURCE, sourceName: '   ', correct: '1' },
      expected: { bookId: null, sourceName: null },
    },
    {
      name: 'kayıtlı kitap seçiliyse kaynak adı yok sayılır',
      v: { bookId: BOOK, sourceName: 'eski metin', correct: '1' },
      expected: { bookId: BOOK, sourceName: null },
    },
    {
      name: 'kitap yok seçiliyse kaynak adı yok sayılır',
      v: { bookId: '', sourceName: 'eski metin', correct: '1' },
      expected: { bookId: null, sourceName: null },
    },
    {
      name: 'soru sayısı boşken boş D/Y/B 0 sayılır',
      v: { blankAuto: false, correct: '7', wrong: '', blank: '' },
      expected: { correct: 7, wrong: 0, blank: 0, topicId: null, label: null },
    },
    {
      name: 'otomatik boş kapalı, toplam soru sayısına eşit',
      v: { blankAuto: false, questionCount: '10', correct: '5', wrong: '3', blank: '2' },
      expected: { correct: 5, wrong: 3, blank: 2 },
    },
    {
      name: 'geçmiş tarih',
      v: { correct: '1', date: '2025-02-28' },
      expected: { date: '2025-02-28' },
    },
  ])('$name', ({ v, expected }) => {
    const validation = validateTestResultForm(values(v), TODAY)
    expect(validation.ok).toBe(true)
    if (validation.ok) expect(validation.input).toMatchObject(expected)
  })
})

describe('validateTestResultForm — hatalar', () => {
  it.each([
    {
      name: 'ders yok',
      v: { subjectId: '', correct: '1' },
      errors: { subjectId: FORM_MESSAGES.subjectRequired },
    },
    {
      name: 'negatif doğru',
      v: { correct: '-1' },
      errors: { correct: FORM_MESSAGES.countInvalid },
    },
    {
      name: 'ondalık yanlış',
      v: { correct: '1', wrong: '1.5' },
      errors: { wrong: FORM_MESSAGES.countInvalid },
    },
    {
      name: 'harfli boş (otomatik kapalı)',
      v: { blankAuto: false, correct: '1', blank: 'a' },
      errors: { blank: FORM_MESSAGES.countInvalid },
    },
    {
      name: 'soru sayısı 0',
      v: { questionCount: '0', correct: '1' },
      errors: { questionCount: FORM_MESSAGES.questionCountInvalid },
    },
    {
      name: 'soru sayısı geçersiz',
      v: { questionCount: '1,5', correct: '1' },
      errors: { questionCount: FORM_MESSAGES.questionCountInvalid },
    },
    {
      name: 'otomatik boşta D+Y soru sayısını aşıyor',
      v: { questionCount: '10', correct: '8', wrong: '5' },
      errors: { questionCount: FORM_MESSAGES.sumExceeds },
    },
    {
      name: 'elle boşta D+Y+B soru sayısını aşıyor',
      v: { blankAuto: false, questionCount: '10', correct: '5', wrong: '3', blank: '3' },
      errors: { questionCount: FORM_MESSAGES.sumExceeds },
    },
    {
      name: 'elle boşta toplam soru sayısından az',
      v: { blankAuto: false, questionCount: '10', correct: '5', wrong: '3', blank: '1' },
      errors: { questionCount: sumMismatchMessage(9, 10) },
    },
    { name: 'hiç soru yok', v: {}, errors: { questionCount: FORM_MESSAGES.noQuestions } },
    {
      name: 'tarih boş',
      v: { correct: '1', date: '' },
      errors: { date: FORM_MESSAGES.dateRequired },
    },
    {
      name: 'tarih biçimsiz',
      v: { correct: '1', date: '19.11.2026' },
      errors: { date: FORM_MESSAGES.dateInvalid },
    },
    {
      name: 'tarih yok (30 Şubat)',
      v: { correct: '1', date: '2026-02-30' },
      errors: { date: FORM_MESSAGES.dateInvalid },
    },
    {
      name: 'gelecek tarih',
      v: { correct: '1', date: '2026-11-20' },
      errors: { date: FORM_MESSAGES.dateInFuture },
    },
    {
      name: 'uzun etiket',
      v: { correct: '1', label: 'x'.repeat(MAX_TEXT_LENGTH + 1) },
      errors: { label: FORM_MESSAGES.textTooLong },
    },
    {
      name: 'uzun kaynak adı',
      v: { correct: '1', bookId: OTHER_SOURCE, sourceName: 'x'.repeat(MAX_TEXT_LENGTH + 1) },
      errors: { sourceName: FORM_MESSAGES.textTooLong },
    },
  ])('$name', ({ v, errors }) => {
    expect(validateTestResultForm(values(v), TODAY)).toEqual({ ok: false, errors })
  })
})

describe('takenAtFor', () => {
  const now = new Date(2026, 10, 19, 21, 45, 10)

  it('bugünse şu anı döner', () => {
    expect(takenAtFor(toISODate(now), now)).toBe(now.toISOString())
  })

  it.each(['2026-11-18', '2026-01-01', '2025-12-31'])('%s → o günün yerel öğleni', (day) => {
    const takenAt = takenAtFor(day, now)
    const local = new Date(takenAt)
    expect(toISODate(local)).toBe(day)
    expect(local.getHours()).toBe(12)
  })
})
