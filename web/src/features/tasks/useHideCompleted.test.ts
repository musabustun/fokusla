import { act, renderHook } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { HIDE_COMPLETED_STORAGE_KEY, useHideCompleted } from './useHideCompleted'

describe('useHideCompleted', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('varsayılan olarak false; değişiklik localStorage’a yazılır', () => {
    const { result } = renderHook(() => useHideCompleted())
    expect(result.current[0]).toBe(false)

    act(() => result.current[1](true))
    expect(result.current[0]).toBe(true)
    expect(localStorage.getItem(HIDE_COMPLETED_STORAGE_KEY)).toBe('true')
  })

  it('kayıtlı tercihi okur', () => {
    localStorage.setItem(HIDE_COMPLETED_STORAGE_KEY, 'true')
    const { result } = renderHook(() => useHideCompleted())
    expect(result.current[0]).toBe(true)
  })

  it('depolama hata verirse çökmez', () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('kapalı')
    })
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('kapalı')
    })
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined)
    const { result } = renderHook(() => useHideCompleted())
    expect(result.current[0]).toBe(false)

    act(() => result.current[1](true))
    expect(result.current[0]).toBe(true)
    expect(warn).toHaveBeenCalled()
  })
})
