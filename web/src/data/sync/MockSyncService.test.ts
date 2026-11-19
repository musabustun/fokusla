import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { SyncState } from './SyncService'
import { MockSyncService, SYNC_ENABLED_KEY } from './MockSyncService'

const NOW = new Date('2026-11-19T07:00:00.000Z')
const create = () => new MockSyncService({ delayMs: 0, now: () => NOW })

describe('MockSyncService', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('starts disabled and syncNow is a no-op while disabled', async () => {
    const sync = create()
    const listener = vi.fn()
    sync.subscribe(listener)
    sync.recordLocalChange({ entity: 'books', id: 'b1', op: 'upsert', at: NOW.toISOString() })

    await sync.syncNow()

    expect(sync.getState()).toEqual({ kind: 'disabled' })
    expect(sync.pendingChangeCount()).toBe(1)
    expect(listener).not.toHaveBeenCalled()
  })

  it('enable → idle, persists the flag, survives a reload', async () => {
    const sync = create()
    await sync.enable()
    expect(sync.getState()).toEqual({ kind: 'idle', lastSyncedAt: null })
    expect(localStorage.getItem(SYNC_ENABLED_KEY)).toBe('true')
    expect(create().getState().kind).toBe('idle')

    await sync.disable()
    expect(sync.getState()).toEqual({ kind: 'disabled' })
    expect(create().getState().kind).toBe('disabled')
  })

  it('syncNow goes syncing → idle, sets lastSyncedAt and clears the queue', async () => {
    const sync = create()
    await sync.enable()
    const states: SyncState[] = []
    sync.subscribe((state) => states.push(state))
    sync.recordLocalChange({ entity: 'books', id: 'b1', op: 'upsert', at: 'a' })

    await sync.syncNow()

    expect(states).toEqual([{ kind: 'syncing' }, { kind: 'idle', lastSyncedAt: NOW.toISOString() }])
    expect(sync.pendingChangeCount()).toBe(0)
  })

  it('dedupes by entity + id and keeps the latest change', () => {
    const sync = create()
    sync.recordLocalChange({ entity: 'books', id: 'b1', op: 'upsert', at: '1' })
    sync.recordLocalChange({ entity: 'books', id: 'b1', op: 'delete', at: '2' })
    sync.recordLocalChange({ entity: 'tasks', id: 'b1', op: 'upsert', at: '3' })

    expect(sync.pendingChangeCount()).toBe(2)
    expect(sync.pendingChanges()).toEqual([
      { entity: 'books', id: 'b1', op: 'delete', at: '2' },
      { entity: 'tasks', id: 'b1', op: 'upsert', at: '3' },
    ])
  })

  it('keeps changes recorded during a sync and ignores overlapping syncNow calls', async () => {
    vi.useFakeTimers()
    try {
      const sync = new MockSyncService({ delayMs: 100, now: () => NOW })
      await sync.enable()
      sync.recordLocalChange({ entity: 'books', id: 'b1', op: 'upsert', at: '1' })
      const running = sync.syncNow()
      sync.recordLocalChange({ entity: 'books', id: 'b1', op: 'upsert', at: '2' })
      await sync.syncNow()
      expect(sync.getState().kind).toBe('syncing')

      await vi.advanceTimersByTimeAsync(100)
      await running

      expect(sync.getState().kind).toBe('idle')
      expect(sync.pendingChanges()).toEqual([{ entity: 'books', id: 'b1', op: 'upsert', at: '2' }])
    } finally {
      vi.useRealTimers()
    }
  })

  it('does not overwrite state when disabled during a sync', async () => {
    vi.useFakeTimers()
    try {
      const sync = new MockSyncService({ delayMs: 100 })
      await sync.enable()
      const running = sync.syncNow()
      await sync.disable()
      await vi.advanceTimersByTimeAsync(100)
      await running
      expect(sync.getState()).toEqual({ kind: 'disabled' })
    } finally {
      vi.useRealTimers()
    }
  })

  it('unsubscribe stops notifications; getState is referentially stable', async () => {
    const sync = create()
    const listener = vi.fn()
    const unsubscribe = sync.subscribe(listener)
    const before = sync.getState()
    expect(sync.getState()).toBe(before)

    await sync.enable()
    expect(listener).toHaveBeenCalledTimes(1)
    unsubscribe()
    await sync.disable()
    expect(listener).toHaveBeenCalledTimes(1)
  })

  it('enable/disable are idempotent and do not re-notify', async () => {
    const sync = create()
    const listener = vi.fn()
    sync.subscribe(listener)
    await sync.disable()
    await sync.enable()
    await sync.enable()
    expect(listener).toHaveBeenCalledTimes(1)
  })
})
