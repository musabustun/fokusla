import { describe, expect, it } from 'vitest'
import type { ExamType, Subject, YksField } from '@/domain'
import { CUSTOM_ORDER_BASE, isCatalogEntity, visibleSubjects } from './subjects'

function subject(
  name: string,
  exam: ExamType,
  fields: YksField[],
  catalogKey: string | null,
  order: number,
): Subject {
  return {
    id: `${exam}-${name}`,
    createdAt: '2026-11-19T00:00:00.000Z',
    updatedAt: '2026-11-19T00:00:00.000Z',
    deletedAt: null,
    name,
    exam,
    fields,
    catalogKey,
    order,
  }
}

const ALL: YksField[] = ['SAY', 'EA', 'SOZ', 'DIL']
const SUBJECTS = [
  subject('Fizik', 'AYT', ['SAY'], 'ayt-fizik', 3),
  subject('Edebiyat', 'AYT', ['EA', 'SOZ'], 'ayt-edebiyat', 1),
  subject('Matematik', 'TYT', ALL, 'tyt-matematik', 1),
  subject('Türkçe', 'TYT', ALL, 'tyt-turkce', 0),
  subject('İngilizce', 'YDT', ['DIL'], 'ydt-ingilizce', 0),
  subject('Özel Deneme', 'AYT', [], null, CUSTOM_ORDER_BASE),
  subject('Çizim', 'TYT', [], null, CUSTOM_ORDER_BASE),
]

const names = (field: YksField) => visibleSubjects(SUBJECTS, field).map((s) => s.name)

describe('visibleSubjects', () => {
  it.each<[YksField, string[]]>([
    ['SAY', ['Türkçe', 'Matematik', 'Çizim', 'Fizik', 'Özel Deneme']],
    ['EA', ['Türkçe', 'Matematik', 'Çizim', 'Edebiyat', 'Özel Deneme']],
    ['SOZ', ['Türkçe', 'Matematik', 'Çizim', 'Edebiyat', 'Özel Deneme']],
    ['DIL', ['Türkçe', 'Matematik', 'Çizim', 'Özel Deneme', 'İngilizce']],
  ])('%s alanı', (field, expected) => {
    expect(names(field)).toEqual(expected)
  })

  it('aynı sırada olanları Türkçe alfabeye göre dizer', () => {
    const list = [
      subject('Şekil', 'TYT', [], null, 5),
      subject('Sayılar', 'TYT', [], null, 5),
      subject('Çember', 'TYT', [], null, 5),
      subject('Cebir', 'TYT', [], null, 5),
    ]
    expect(visibleSubjects(list, 'SAY').map((s) => s.name)).toEqual([
      'Cebir',
      'Çember',
      'Sayılar',
      'Şekil',
    ])
  })

  it('girdiyi değiştirmez ve boş listede boş döner', () => {
    const copy = [...SUBJECTS]
    visibleSubjects(SUBJECTS, 'SAY')
    expect(SUBJECTS).toEqual(copy)
    expect(visibleSubjects([], 'EA')).toEqual([])
  })
})

describe('isCatalogEntity', () => {
  it.each([
    [{ catalogKey: 'tyt-matematik' }, true],
    [{ catalogKey: '' }, true],
    [{ catalogKey: null }, false],
  ])('%o → %s', (entity, expected) => {
    expect(isCatalogEntity(entity)).toBe(expected)
  })
})
