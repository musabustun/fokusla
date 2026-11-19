import { describe, expect, it } from 'vitest'
import { validateEntityName } from './entityName'

describe('validateEntityName', () => {
  it.each([
    { raw: 'Geometri', max: 60, expected: { ok: true, name: 'Geometri' } },
    { raw: '  Paragraf   Soruları ', max: 60, expected: { ok: true, name: 'Paragraf Soruları' } },
    { raw: '', max: 5, expected: { ok: false, error: 'Ders adı boş olamaz.' } },
    { raw: '   ', max: 5, expected: { ok: false, error: 'Ders adı boş olamaz.' } },
    { raw: 'abcde', max: 5, expected: { ok: true, name: 'abcde' } },
    {
      raw: 'abcdef',
      max: 5,
      expected: { ok: false, error: 'Ders adı en fazla 5 karakter olabilir.' },
    },
  ])('"$raw" → $expected', ({ raw, max, expected }) => {
    expect(validateEntityName(raw, 'Ders adı', max)).toEqual(expected)
  })
})
