import { describe, expect, it } from 'vitest'
import type { PresenceState, SocialPresence } from '@/domain'
import {
  heartbeat,
  nextPresenceState,
  SIMULATED_ROOMS,
  SIMULATED_USERS,
  simulatedUserId,
  simulatePresence,
} from './simulatedUsers'

const NOW = new Date('2026-11-19T07:00:00.000Z')
const LATER = new Date(NOW.getTime() + 60_000)

const presence = (overrides: Partial<SocialPresence> = {}): SocialPresence => ({
  state: 'focusing',
  sessionStartedAt: '2026-11-19T06:00:00.000Z',
  stateSince: '2026-11-19T06:30:00.000Z',
  todayFocusMs: 1000,
  updatedAt: NOW.toISOString(),
  ...overrides,
})

describe('simulatedUsers', () => {
  it('derives stable user ids from usernames', () => {
    expect(simulatedUserId('elif.say')).toBe('mock-user-elif-say')
    expect(simulatedUserId('mert_ayt')).toBe('mock-user-mert-ayt')
    expect(SIMULATED_USERS.map((u) => u.userId)).toContain('mock-user-can-tyt')
  })

  it('has unique usernames, invite codes and rooms hosted by simulated users', () => {
    const codes = [
      ...SIMULATED_USERS.map((u) => u.inviteCode),
      ...SIMULATED_ROOMS.map((r) => r.inviteCode),
    ]
    expect(new Set(codes).size).toBe(codes.length)
    const ids = new Set(SIMULATED_USERS.map((u) => u.userId))
    for (const room of SIMULATED_ROOMS) {
      expect(ids.has(room.hostUserId)).toBe(true)
      expect(room.members.every((m) => ids.has(m.userId))).toBe(true)
    }
  })

  it.each<[PresenceState, number, PresenceState]>([
    ['focusing', 0, 'onBreak'],
    ['focusing', 0.019, 'onBreak'],
    ['focusing', 0.02, 'offline'],
    ['focusing', 0.0219, 'offline'],
    ['focusing', 0.022, 'focusing'],
    ['onBreak', 0.099, 'focusing'],
    ['onBreak', 0.1, 'onBreak'],
    ['offline', 0.0049, 'focusing'],
    ['offline', 0.005, 'offline'],
  ])('nextPresenceState(%s, %s) → %s', (state, r, expected) => {
    expect(nextPresenceState(state, r)).toBe(expected)
  })

  it('heartbeat accrues focus time only while focusing', () => {
    expect(heartbeat(presence(), LATER)).toEqual(
      presence({ todayFocusMs: 61_000, updatedAt: LATER.toISOString() }),
    )
    expect(heartbeat(presence({ state: 'onBreak' }), LATER)).toEqual(
      presence({ state: 'onBreak', updatedAt: LATER.toISOString() }),
    )
    const offline = presence({ state: 'offline' })
    expect(heartbeat(offline, LATER)).toBe(offline)
  })

  it('heartbeat ignores negative clock drift', () => {
    const earlier = new Date(NOW.getTime() - 5000)
    expect(heartbeat(presence(), earlier).todayFocusMs).toBe(1000)
  })

  it('simulatePresence keeps the session when switching between focus and break', () => {
    const input = presence()
    const next = simulatePresence(input, 0.01, LATER)

    expect(next).toEqual({
      state: 'onBreak',
      sessionStartedAt: input.sessionStartedAt,
      stateSince: LATER.toISOString(),
      todayFocusMs: 61_000,
      updatedAt: LATER.toISOString(),
    })
    expect(input.state).toBe('focusing')
  })

  it('simulatePresence starts a new session when coming online', () => {
    const offline = presence({ state: 'offline', sessionStartedAt: null, stateSince: null })
    expect(simulatePresence(offline, 0, LATER)).toMatchObject({
      state: 'focusing',
      sessionStartedAt: LATER.toISOString(),
      stateSince: LATER.toISOString(),
      todayFocusMs: 1000,
    })
    expect(simulatePresence(offline, 0.9, LATER)).toBe(offline)
  })
})
