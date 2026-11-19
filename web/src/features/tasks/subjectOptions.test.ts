import { describe, expect, it } from 'vitest'
import type { Subject } from '@/domain'
import { subjectGroups } from './subjectOptions'

function subject(partial: Partial<Subject> & Pick<Subject, 'id' | 'name' | 'exam'>): Subject {
  return {
    fields: ['SAY', 'EA', 'SOZ', 'DIL'],
    catalogKey: null,
    order: 0,
    createdAt: '2026-11-19T00:00:00.000Z',
    updatedAt: '2026-11-19T00:00:00.000Z',
    deletedAt: null,
    ...partial,
  }
}

const SUBJECTS: Subject[] = [
  subject({ id: 'fiz', name: 'Fizik', exam: 'AYT', fields: ['SAY'], order: 2 }),
  subject({ id: 'mat', name: 'Matematik', exam: 'AYT', fields: ['SAY', 'EA'], order: 1 }),
  subject({ id: 'tur', name: 'Türkçe', exam: 'TYT', order: 0 }),
  subject({ id: 'ing', name: 'İngilizce', exam: 'YDT', fields: ['DIL'], order: 0 }),
  subject({ id: 'tar', name: 'Tarih', exam: 'AYT', fields: ['SOZ', 'EA'], order: 3 }),
  subject({ id: 'sil', name: 'Silinmiş', exam: 'TYT', deletedAt: '2026-11-19T00:00:00.000Z' }),
]

const ids = (groups: ReturnType<typeof subjectGroups>) =>
  groups.map((group) => [group.exam, group.subjects.map((s) => s.id)])

describe('subjectGroups', () => {
  it('alanın derslerini sınav ve sıraya göre gruplar', () => {
    expect(ids(subjectGroups(SUBJECTS, 'SAY'))).toEqual([
      ['TYT', ['tur']],
      ['AYT', ['mat', 'fiz']],
    ])
    expect(ids(subjectGroups(SUBJECTS, 'DIL'))).toEqual([
      ['TYT', ['tur']],
      ['YDT', ['ing']],
    ])
  })

  it('alan yoksa tüm silinmemiş dersleri gösterir', () => {
    expect(ids(subjectGroups(SUBJECTS, undefined))).toEqual([
      ['TYT', ['tur']],
      ['AYT', ['mat', 'fiz', 'tar']],
      ['YDT', ['ing']],
    ])
  })

  it('düzenlenen görevin dersini alan dışında da tutar', () => {
    expect(ids(subjectGroups(SUBJECTS, 'SAY', 'tar'))).toEqual([
      ['TYT', ['tur']],
      ['AYT', ['mat', 'fiz', 'tar']],
    ])
  })
})
