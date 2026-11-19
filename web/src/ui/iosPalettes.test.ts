/// <reference types="node" />
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { toIosPalettesJson } from './iosPalettes'
import { PALETTE_NAMES } from './tokens'

const jsonPath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '../../../ios/FokusKit/Tests/FokusDesignTests/Fixtures/palettes.web.json',
)

describe('iOS palet dışa aktarımı', () => {
  it('commit edilen palettes.web.json web token’larıyla aynı (drift koruması)', () => {
    const committed: unknown = JSON.parse(readFileSync(jsonPath, 'utf8'))
    expect(committed).toEqual(toIosPalettesJson())
  })

  it('palet sırası seçicideki sırayla aynı', () => {
    expect(toIosPalettesJson().order).toEqual([...PALETTE_NAMES])
  })
})
