import { describe, expect, it } from 'vitest'
import type { SyncState } from '@/data'
import { formatSyncStatus } from './formatSyncStatus'

describe('formatSyncStatus', () => {
  const cases: readonly [string, SyncState, RegExp][] = [
    ['disabled', { kind: 'disabled' }, /^Kapalı$/],
    ['syncing', { kind: 'syncing' }, /^Senkronize ediliyor…$/],
    ['error', { kind: 'error', message: 'Ağ yok' }, /^Hata: Ağ yok$/],
    ['never synced', { kind: 'idle', lastSyncedAt: null }, /henüz senkronize edilmedi/],
    [
      'synced',
      { kind: 'idle', lastSyncedAt: '2026-11-19T10:30:00.000Z' },
      /^Son senkron: 19 Kasım 2026/,
    ],
  ]

  it.each(cases)('describes %s', (_name, state, expected) => {
    expect(formatSyncStatus(state)).toMatch(expected)
  })
})
