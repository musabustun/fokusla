/// <reference types="node" />
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { toIosCurriculumJson } from './iosExport'
import { yksCurriculum } from './yks'

const jsonPath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '../../../ios/FokusKit/Sources/FokusData/Resources/yks-curriculum.json',
)

describe('iOS müfredat dışa aktarımı', () => {
  it('commit edilen yks-curriculum.json web kataloğuyla aynı (drift koruması)', () => {
    const committed: unknown = JSON.parse(readFileSync(jsonPath, 'utf8'))
    expect(committed).toEqual(toIosCurriculumJson(yksCurriculum))
  })

  it('ders anahtar sırası kararlıdır', () => {
    const [subject] = toIosCurriculumJson(yksCurriculum).subjects
    expect(Object.keys(subject ?? {})).toEqual([
      'key',
      'name',
      'exam',
      'fields',
      'questionCount',
      'topics',
    ])
  })
})
