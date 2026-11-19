import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { KeyValueStorage } from '../storage'
import {
  AUTH_SESSION_KEY,
  MOCK_APPLE_USER_ID_KEY,
  MockAuthService,
  parseAuthSession,
} from './MockAuthService'

describe('MockAuthService', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('has no session initially', async () => {
    expect(await new MockAuthService({ delayMs: 0 }).getSession()).toBeNull()
  })

  it('signs in with a mock Apple id and persists the session', async () => {
    const auth = new MockAuthService({ delayMs: 0 })
    const session = await auth.signInWithApple()

    expect(session).toEqual({
      appleUserId: expect.stringMatching(/^mock-apple-[0-9a-f-]{36}$/),
      displayName: null,
      email: null,
      isMock: true,
    })
    // Yeni bir örnek (sayfa yenileme) aynı oturumu okur.
    expect(await new MockAuthService({ delayMs: 0 }).getSession()).toEqual(session)
  })

  it('keeps the mock Apple id stable across sign-out and sign-in', async () => {
    const auth = new MockAuthService({ delayMs: 0 })
    const first = await auth.signInWithApple()
    await auth.signOut()
    expect(await auth.getSession()).toBeNull()
    expect(localStorage.getItem(AUTH_SESSION_KEY)).toBeNull()
    const second = await auth.signInWithApple()
    expect(second.appleUserId).toBe(first.appleUserId)
    expect(localStorage.getItem(MOCK_APPLE_USER_ID_KEY)).toBe(first.appleUserId)
  })

  it('deleteAccount clears the session and the mock Apple id', async () => {
    const auth = new MockAuthService({ delayMs: 0 })
    const first = await auth.signInWithApple()
    await auth.deleteAccount()
    expect(await auth.getSession()).toBeNull()
    expect(localStorage.getItem(MOCK_APPLE_USER_ID_KEY)).toBeNull()
    const second = await auth.signInWithApple()
    expect(second.appleUserId).not.toBe(first.appleUserId)
  })

  it('treats corrupt or foreign stored data as no session', async () => {
    const auth = new MockAuthService({ delayMs: 0 })
    for (const raw of ['{bozuk', '42', 'null', '{"appleUserId":""}', '{"foo":1}']) {
      localStorage.setItem(AUTH_SESSION_KEY, raw)
      expect(await auth.getSession()).toBeNull()
    }
  })

  it('applies the artificial delay', async () => {
    vi.useFakeTimers()
    try {
      const auth = new MockAuthService({ delayMs: 400 })
      let done = false
      const pending = auth.signInWithApple().then(() => (done = true))
      await vi.advanceTimersByTimeAsync(399)
      expect(done).toBe(false)
      await vi.advanceTimersByTimeAsync(1)
      await pending
      expect(done).toBe(true)
    } finally {
      vi.useRealTimers()
    }
  })

  it('never throws when storage is unavailable or broken', async () => {
    vi.spyOn(console, 'warn').mockImplementation(() => undefined)
    const broken: KeyValueStorage = {
      getItem: () => {
        throw new Error('SecurityError')
      },
      setItem: () => {
        throw new Error('QuotaExceededError')
      },
      removeItem: () => {
        throw new Error('SecurityError')
      },
    }
    for (const storage of [broken, null]) {
      const auth = new MockAuthService({ delayMs: 0, storage })
      expect(await auth.getSession()).toBeNull()
      const session = await auth.signInWithApple()
      expect(session.isMock).toBe(true)
      await expect(auth.signOut()).resolves.toBeUndefined()
      await expect(auth.deleteAccount()).resolves.toBeUndefined()
    }
  })
})

describe('parseAuthSession', () => {
  it('accepts a valid shape and strips unknown fields', () => {
    const raw = JSON.stringify({
      appleUserId: 'a',
      displayName: 'Ali',
      email: null,
      isMock: false,
      extra: 1,
    })
    expect(parseAuthSession(raw)).toEqual({
      appleUserId: 'a',
      displayName: 'Ali',
      email: null,
      isMock: false,
    })
  })

  it('rejects wrong field types', () => {
    const valid = { appleUserId: 'a', displayName: null, email: null, isMock: true }
    expect(parseAuthSession(null)).toBeNull()
    expect(parseAuthSession(JSON.stringify({ ...valid, displayName: 1 }))).toBeNull()
    expect(parseAuthSession(JSON.stringify({ ...valid, email: false }))).toBeNull()
    expect(parseAuthSession(JSON.stringify({ ...valid, isMock: 'yes' }))).toBeNull()
  })
})
