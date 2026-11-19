import { describe, expect, it } from 'vitest'
import { analysisHref, readSelection } from './analysisLinks'

describe('analysisHref', () => {
  it.each([
    [{}, '/analiz'],
    [{ subjectId: null }, '/analiz'],
    [{ subjectId: 's1' }, '/analiz?ders=s1'],
    [{ subjectId: 's1', topicId: 't1' }, '/analiz?ders=s1&konu=t1'],
    [{ subjectId: 's1', topicId: null }, '/analiz?ders=s1'],
    [{ topicId: 't1' }, '/analiz'],
  ])('%o → %s', (selection, expected) => {
    expect(analysisHref(selection)).toBe(expected)
  })

  it('parametresiz çağrı genel bakışa gider', () => {
    expect(analysisHref()).toBe('/analiz')
  })
})

describe('readSelection', () => {
  it.each([
    ['', { subjectId: null, topicId: null }],
    ['ders=s1', { subjectId: 's1', topicId: null }],
    ['ders=s1&konu=t1', { subjectId: 's1', topicId: 't1' }],
    ['konu=t1', { subjectId: null, topicId: null }],
    ['ders=&konu=t1', { subjectId: null, topicId: null }],
    ['ders=s1&konu=', { subjectId: 's1', topicId: null }],
  ])('"%s"', (query, expected) => {
    expect(readSelection(new URLSearchParams(query))).toEqual(expected)
  })
})
