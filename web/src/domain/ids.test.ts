import { describe, expect, it } from 'vitest'
import { catalogEntityId, newId, toISODate, toISODateTime, uuidV5 } from './ids'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

describe('ids', () => {
  it('newId küçük harfli v4 UUID üretir', () => {
    expect(newId()).toMatch(UUID_RE)
    expect(newId()).not.toBe(newId())
  })

  it('uuidV5 RFC 4122 test vektörüyle eşleşir', async () => {
    const dnsNamespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8'
    await expect(uuidV5('www.example.com', dnsNamespace)).resolves.toBe(
      '2ed6657d-e927-568b-95e1-2665a8aea6a2',
    )
  })

  it('catalogEntityId deterministiktir ve anahtara göre değişir', async () => {
    const a1 = await catalogEntityId('tyt-matematik')
    const a2 = await catalogEntityId('tyt-matematik')
    const b = await catalogEntityId('tyt-geometri')
    expect(a1).toBe(a2)
    expect(a1).not.toBe(b)
    expect(a1).toMatch(UUID_RE)
  })

  it('toISODateTime ve toISODate biçimleri', () => {
    const date = new Date(2026, 10, 19, 9, 5)
    expect(toISODateTime(date)).toBe(date.toISOString())
    expect(toISODate(date)).toBe('2026-11-19')
  })
})
