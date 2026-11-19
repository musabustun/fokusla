import { act, renderHook, waitFor } from '@testing-library/react'
import Dexie from 'dexie'
import type { ReactNode } from 'react'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createServices } from './createServices'
import { useCurrentProfile, useLiveData, useSyncState } from './hooks'
import { ServicesProvider } from './ServicesContext'
import type { AppServices } from './services'

describe('data hooks', () => {
  let dbName: string
  let services: AppServices
  let wrapper: (props: { children: ReactNode }) => ReactNode

  beforeEach(() => {
    localStorage.clear()
    dbName = crypto.randomUUID()
    services = createServices({ dbName, authDelayMs: 0, syncDelayMs: 0 })
    wrapper = ({ children }) => <ServicesProvider services={services}>{children}</ServicesProvider>
  })

  afterEach(async () => {
    await Dexie.delete(dbName)
  })

  it('useLiveData re-runs the query after a repository write', async () => {
    const { result } = renderHook(() =>
      useLiveData(() => services.repositories.tasks.findAll(), []),
    )
    await waitFor(() => expect(result.current).toEqual([]))

    await act(async () => {
      await services.repositories.tasks.create({
        title: 'Paragraf çöz',
        kind: 'assignment',
        notes: null,
        subjectId: null,
        dueDate: '2026-11-20',
        recurrence: null,
        completedAt: null,
        order: 0,
      })
    })

    await waitFor(() => expect(result.current?.map((t) => t.title)).toEqual(['Paragraf çöz']))
  })

  it('useCurrentProfile distinguishes loading, absent and present', async () => {
    const { result } = renderHook(() => useCurrentProfile(), { wrapper })
    expect(result.current).toEqual({ status: 'loading' })
    await waitFor(() => expect(result.current).toEqual({ status: 'ready', profile: undefined }))

    const profile = await act(() =>
      services.repositories.profiles.create({
        displayName: 'Deniz',
        field: 'SAY',
        appleUserId: null,
        targetExamYear: 2027,
        onboardingCompletedAt: null,
      }),
    )

    await waitFor(() => expect(result.current).toEqual({ status: 'ready', profile }))
  })

  it('useSyncState follows sync state transitions', async () => {
    const { result } = renderHook(() => useSyncState(), { wrapper })
    expect(result.current).toEqual({ kind: 'disabled' })

    await act(() => services.sync.enable())
    expect(result.current).toEqual({ kind: 'idle', lastSyncedAt: null })

    await act(() => services.sync.syncNow())
    expect(result.current.kind).toBe('idle')
  })
})
