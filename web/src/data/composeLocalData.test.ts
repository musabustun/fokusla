import { describe, expect, it, vi } from 'vitest'
import { withLocalDataParticipants, type LocalDataParticipant } from './composeLocalData'
import { DATA_EXPORT_FORMAT_VERSION, type DataExport, type LocalDataService } from './localData'

const BASE_EXPORT = {
  app: 'fokus',
  formatVersion: DATA_EXPORT_FORMAT_VERSION,
  exportedAt: '2026-11-19T07:00:00.000Z',
  entities: {},
} as unknown as DataExport

function fakeBase(calls: string[]): LocalDataService {
  return {
    exportAll: vi.fn(async () => BASE_EXPORT),
    deleteAll: vi.fn(async () => {
      calls.push('base')
    }),
  }
}

function participant(key: string, data: unknown, calls: string[]): LocalDataParticipant {
  return {
    key,
    exportData: async () => data,
    clearData: async () => {
      calls.push(key)
    },
  }
}

describe('withLocalDataParticipants', () => {
  it('returns the base export unchanged when there are no participants', async () => {
    const service = withLocalDataParticipants(fakeBase([]), [])

    await expect(service.exportAll()).resolves.toBe(BASE_EXPORT)
  })

  it('adds each participant export under its key without mutating the base export', async () => {
    const calls: string[] = []
    const service = withLocalDataParticipants(fakeBase(calls), [
      participant('social', { username: 'ben.yks' }, calls),
      participant('other', null, calls),
    ])

    const backup = await service.exportAll()

    expect(backup.extras).toEqual({ social: { username: 'ben.yks' }, other: null })
    expect(backup.entities).toBe(BASE_EXPORT.entities)
    expect(BASE_EXPORT.extras).toBeUndefined()
  })

  it('clears the base data first, then every participant in order', async () => {
    const calls: string[] = []
    const service = withLocalDataParticipants(fakeBase(calls), [
      participant('social', null, calls),
      participant('other', null, calls),
    ])

    await service.deleteAll()

    expect(calls).toEqual(['base', 'social', 'other'])
  })

  it('still clears later participants when one fails, then reports the failure', async () => {
    const calls: string[] = []
    const failing: LocalDataParticipant = {
      key: 'broken',
      exportData: async () => null,
      clearData: async () => {
        throw new Error('boom')
      },
    }
    const service = withLocalDataParticipants(fakeBase(calls), [
      failing,
      participant('social', null, calls),
    ])

    await expect(service.deleteAll()).rejects.toThrow('boom')
    expect(calls).toEqual(['base', 'social'])
  })
})
