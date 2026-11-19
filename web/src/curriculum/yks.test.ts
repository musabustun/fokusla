import { describe, expect, it } from 'vitest'
import type { ExamType, YksField } from '@/domain'
import { findSubject, FIELD_DESCRIPTIONS, FIELD_LABELS, subjectsForField } from './helpers'
import { EXAM_QUESTION_TOTALS, YKS_TESTS } from './structure'
import { yksCurriculum } from './yks'

const SLUG = '[a-z0-9]+(?:-[a-z0-9]+)*'
const SUBJECT_KEY_RE = new RegExp(`^${SLUG}$`)
const TOPIC_KEY_RE = new RegExp(`^${SLUG}\\.${SLUG}$`)
const FIELDS: YksField[] = ['SAY', 'EA', 'SOZ', 'DIL']
const EXAMS: ExamType[] = ['TYT', 'AYT', 'YDT']

const { subjects } = yksCurriculum
const allTopics = subjects.flatMap((subject) => subject.topics)

const keysFor = (field: YksField) => subjectsForField(yksCurriculum, field).map((s) => s.key)

describe('yksCurriculum metadata', () => {
  it('has a valid exam year, verification date and at least one URL source', () => {
    expect(yksCurriculum.examYear).toBeGreaterThanOrEqual(2026)
    expect(yksCurriculum.verifiedAt).toMatch(/^\d{4}-\d{2}-\d{2}$/)
    expect(yksCurriculum.sources.some((source) => source.includes('https://'))).toBe(true)
  })
})

describe('yksCurriculum keys', () => {
  it('has unique subject keys', () => {
    const keys = subjects.map((subject) => subject.key)
    expect(new Set(keys).size).toBe(keys.length)
  })

  it('has unique topic keys across the whole catalog', () => {
    const keys = allTopics.map((topic) => topic.key)
    expect(new Set(keys).size).toBe(keys.length)
  })

  it('uses ASCII kebab-case subject keys prefixed by the exam', () => {
    for (const subject of subjects) {
      expect(subject.key).toMatch(SUBJECT_KEY_RE)
      expect(subject.key.startsWith(`${subject.exam.toLowerCase()}-`)).toBe(true)
    }
  })

  it('prefixes every topic key with its subject key', () => {
    for (const subject of subjects) {
      for (const topic of subject.topics) {
        expect(topic.key).toMatch(TOPIC_KEY_RE)
        expect(topic.key.startsWith(`${subject.key}.`)).toBe(true)
      }
    }
  })
})

describe('yksCurriculum content', () => {
  it('gives every subject at least one topic', () => {
    for (const subject of subjects) {
      expect(subject.topics.length, subject.key).toBeGreaterThan(0)
    }
  })

  it('has non-empty, trimmed subject and topic names', () => {
    const names = [...subjects.map((s) => s.name), ...allTopics.map((t) => t.name)]
    for (const name of names) {
      expect(name.length).toBeGreaterThan(0)
      expect(name).toBe(name.trim())
    }
  })

  it('lists TYT subjects first, then AYT, then YDT', () => {
    const examOrder = subjects.map((subject) => EXAMS.indexOf(subject.exam))
    expect(examOrder).toEqual([...examOrder].sort((a, b) => a - b))
  })

  it('assigns every TYT subject to all four fields', () => {
    for (const subject of subjects.filter((s) => s.exam === 'TYT')) {
      expect([...subject.fields].sort()).toEqual([...FIELDS].sort())
    }
  })
})

describe('question counts (ÖSYM 2026-YKS Kılavuzu, Tablo 1B)', () => {
  it('assigns every catalog subject to exactly one ÖSYM test of the same exam', () => {
    for (const subject of subjects) {
      const tests = YKS_TESTS.filter((test) => test.subjectKeys.includes(subject.key))
      expect(tests, subject.key).toHaveLength(1)
      expect(tests[0]?.exam).toBe(subject.exam)
    }
  })

  it('references only existing subjects from the test structure', () => {
    for (const test of YKS_TESTS) {
      for (const key of test.subjectKeys) {
        expect(findSubject(yksCurriculum, key), key).toBeDefined()
      }
    }
  })

  it('sums tests to 120 (TYT), 160 (AYT) and 80 (YDT)', () => {
    expect(EXAM_QUESTION_TOTALS).toEqual({ TYT: 120, AYT: 160, YDT: 80 })
    for (const exam of EXAMS) {
      const total = YKS_TESTS.filter((t) => t.exam === exam).reduce(
        (sum, t) => sum + t.questionCount,
        0,
      )
      expect(total, exam).toBe(EXAM_QUESTION_TOTALS[exam])
    }
  })

  it('matches each test total with its subjects (split math/geometry counts are null)', () => {
    for (const test of YKS_TESTS) {
      const counts = test.subjectKeys.map((key) => findSubject(yksCurriculum, key)?.questionCount)
      const known = counts.filter((count): count is number => typeof count === 'number')
      const sum = known.reduce((total, count) => total + count, 0)
      if (known.length === counts.length) {
        expect(sum, test.key).toBe(test.questionCount)
      } else {
        expect(known, test.key).toHaveLength(0)
      }
    }
  })

  it('keeps the documented per-subject counts', () => {
    const count = (key: string) => findSubject(yksCurriculum, key)?.questionCount
    expect(count('tyt-turkce')).toBe(40)
    expect(count('tyt-fizik')).toBe(7)
    expect(count('tyt-biyoloji')).toBe(6)
    expect(count('ayt-edebiyat')).toBe(24)
    expect(count('ayt-tarih-1')).toBe(10)
    expect(count('ayt-cografya-1')).toBe(6)
    expect(count('ayt-tarih-2')).toBe(11)
    expect(count('ayt-cografya-2')).toBe(11)
    expect(count('ayt-felsefe-grubu')).toBe(12)
    expect(count('ayt-din')).toBe(6)
    expect(count('ayt-fizik')).toBe(14)
    expect(count('ayt-kimya')).toBe(13)
    expect(count('ayt-biyoloji')).toBe(13)
    expect(count('ydt-yabanci-dil')).toBe(80)
    expect(count('tyt-matematik')).toBeNull()
    expect(count('ayt-geometri')).toBeNull()
  })
})

describe('subjectsForField', () => {
  const tytKeys = subjects.filter((s) => s.exam === 'TYT').map((s) => s.key)

  it('always starts with all TYT subjects in catalog order', () => {
    for (const field of FIELDS) {
      expect(keysFor(field).slice(0, tytKeys.length)).toEqual(tytKeys)
    }
  })

  it('gives SAY the AYT math and science tests and no social tests', () => {
    const keys = keysFor('SAY')
    expect(keys).toEqual(
      expect.arrayContaining([
        'ayt-matematik',
        'ayt-geometri',
        'ayt-fizik',
        'ayt-kimya',
        'ayt-biyoloji',
      ]),
    )
    expect(keys).not.toContain('ayt-tarih-2')
    expect(keys).not.toContain('ayt-edebiyat')
    expect(keys).not.toContain('ydt-yabanci-dil')
  })

  it('gives EA AYT math, literature, Tarih-1 and Coğrafya-1 only', () => {
    const aytKeys = keysFor('EA').filter((key) => key.startsWith('ayt-'))
    expect(aytKeys).toEqual([
      'ayt-edebiyat',
      'ayt-tarih-1',
      'ayt-cografya-1',
      'ayt-matematik',
      'ayt-geometri',
    ])
  })

  it('gives SÖZ both social tests and no AYT math or science', () => {
    const keys = keysFor('SOZ')
    expect(keys).toEqual(
      expect.arrayContaining([
        'ayt-edebiyat',
        'ayt-tarih-1',
        'ayt-cografya-1',
        'ayt-tarih-2',
        'ayt-cografya-2',
        'ayt-felsefe-grubu',
        'ayt-din',
      ]),
    )
    expect(keys).not.toContain('ayt-fizik')
    expect(keys).not.toContain('ayt-matematik')
  })

  it('gives DİL the YDT and no AYT subjects', () => {
    const keys = keysFor('DIL')
    expect(keys).toContain('ydt-yabanci-dil')
    expect(keys.some((key) => key.startsWith('ayt-'))).toBe(false)
  })
})

describe('findSubject', () => {
  it('returns the subject for a known key and undefined otherwise', () => {
    expect(findSubject(yksCurriculum, 'ayt-fizik')?.name).toBe('Fizik')
    expect(findSubject(yksCurriculum, 'yok-boyle-ders')).toBeUndefined()
  })
})

describe('field labels', () => {
  it('has a Turkish label and description for every field', () => {
    expect(FIELD_LABELS).toEqual({ SAY: 'Sayısal', EA: 'Eşit Ağırlık', SOZ: 'Sözel', DIL: 'Dil' })
    for (const field of FIELDS) {
      expect(FIELD_DESCRIPTIONS[field].trim().length).toBeGreaterThan(0)
    }
  })
})
