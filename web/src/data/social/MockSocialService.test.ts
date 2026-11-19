import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { SocialPresence } from '@/domain'
import type { AuthService, AuthSession } from '../auth/AuthService'
import { MockSocialService, type MockSocialServiceOptions } from './MockSocialService'
import { SOCIAL_MOCK_STORAGE_KEY } from './mockSocialStore'
import { simulatedUserId } from './simulatedUsers'
import { ROOM_NAME_MAX_LENGTH, SocialError, type SocialErrorCode } from './SocialService'

const NOW = new Date('2026-11-19T07:00:00.000Z')
const MINUTE = 60 * 1000
const SESSION: AuthSession = {
  appleUserId: 'mock-apple-1',
  displayName: null,
  email: null,
  isMock: true,
}
const ELIF = simulatedUserId('elif.say')
const MERT = simulatedUserId('mert_ayt')
const ZEYNEP = simulatedUserId('zeynep2027')
const DENIZ = simulatedUserId('deniz_ea')
const CAN = simulatedUserId('can.tyt')
const ECE = simulatedUserId('ece_dil')
const INVITE_CODE = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/

class FakeAuth implements AuthService {
  session: AuthSession | null = null
  async getSession() {
    return this.session
  }
  async signInWithApple() {
    this.session = SESSION
    return SESSION
  }
  async signOut() {
    this.session = null
  }
  async deleteAccount() {
    this.session = null
  }
}

/** Deterministik sözde rastgele üreteç (mulberry32). */
function seeded(seed: number): () => number {
  let a = seed
  return () => {
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

const created: MockSocialService[] = []

function setup(options: Partial<MockSocialServiceOptions> = {}) {
  const auth = new FakeAuth()
  let clock = NOW
  let queued: number[] = []
  const fallback = seeded(42)
  const service = new MockSocialService({
    auth,
    storage: localStorage,
    now: () => clock,
    random: () => {
      const [next, ...rest] = queued
      queued = rest
      return next ?? fallback()
    },
    delayMs: 0,
    tickMs: 0,
    responseDelayMs: 0,
    ...options,
  })
  created.push(service)
  return {
    service,
    auth,
    advanceClock: (ms: number) => {
      clock = new Date(clock.getTime() + ms)
    },
    queueRandom: (...values: number[]) => {
      queued = [...queued, ...values]
    },
  }
}

async function readySetup(options: Partial<MockSocialServiceOptions> = {}) {
  const ctx = setup(options)
  ctx.auth.session = SESSION
  await ctx.service.refresh()
  await ctx.service.claimUsername('ben.yks')
  return ctx
}

async function expectSocialError(promise: Promise<unknown>, code: SocialErrorCode) {
  const error = await promise.then(
    () => null,
    (e: unknown) => e,
  )
  expect(error).toBeInstanceOf(SocialError)
  expect((error as SocialError).code).toBe(code)
}

const presence = (overrides: Partial<SocialPresence> = {}): SocialPresence => ({
  state: 'focusing',
  sessionStartedAt: NOW.toISOString(),
  stateSince: NOW.toISOString(),
  todayFocusMs: 30 * MINUTE,
  updatedAt: NOW.toISOString(),
  ...overrides,
})

beforeEach(() => {
  localStorage.clear()
})

afterEach(() => {
  for (const service of created.splice(0)) service.dispose()
  vi.useRealTimers()
})

describe('MockSocialService — durum ve profil', () => {
  it('starts in loading and becomes signedOut without a session', async () => {
    const { service } = setup()
    expect(service.getSnapshot()).toEqual({
      status: 'loading',
      profile: null,
      friends: [],
      requests: [],
      room: null,
      friendRooms: [],
    })

    await service.refresh()

    expect(service.getSnapshot().status).toBe('signedOut')
    expect(service.getSnapshot().profile).toBeNull()
  })

  it('needs a username when signed in without a stored profile', async () => {
    const { service, auth } = setup()
    auth.session = SESSION

    await service.refresh()

    expect(service.getSnapshot()).toMatchObject({ status: 'needsUsername', profile: null })
  })

  it('waits for the fake latency before resolving', async () => {
    vi.useFakeTimers()
    const { service } = setup({ delayMs: 250 })
    const done = vi.fn()

    void service.refresh().then(done)
    await vi.advanceTimersByTimeAsync(249)
    expect(done).not.toHaveBeenCalled()
    await vi.advanceTimersByTimeAsync(1)

    expect(done).toHaveBeenCalled()
    expect(service.getSnapshot().status).toBe('signedOut')
  })

  it('checkUsername validates format, simulated and reserved names', async () => {
    const { service } = setup()

    expect(await service.checkUsername('ab')).toEqual({ ok: false, problem: 'tooShort' })
    expect(await service.checkUsername('1abc')).toEqual({
      ok: false,
      problem: 'mustStartWithLetter',
    })
    expect(await service.checkUsername('Elif.Say')).toEqual({ ok: false, problem: 'taken' })
    expect(await service.checkUsername('destek')).toEqual({ ok: false, problem: 'taken' })
    expect(await service.checkUsername(' @Ben.YKS ')).toEqual({ ok: true, username: 'ben.yks' })
  })

  it('checkUsername does not report my own username as taken', async () => {
    const { service } = await readySetup()
    expect(await service.checkUsername('ben.yks')).toEqual({ ok: true, username: 'ben.yks' })
  })

  it('claimUsername rejects missing session, invalid and taken names', async () => {
    const { service, auth } = setup()
    await expectSocialError(service.claimUsername('ben.yks'), 'notSignedIn')

    auth.session = SESSION
    await expectSocialError(service.claimUsername('a!'), 'invalidUsername')
    await expectSocialError(service.claimUsername('mert_ayt'), 'usernameTaken')
    await expectSocialError(service.claimUsername('admin'), 'usernameTaken')
    expect(service.getSnapshot().status).toBe('needsUsername')
  })

  it('first claim creates the profile and seeds friends and an incoming request', async () => {
    const { service } = await readySetup()
    const snapshot = service.getSnapshot()

    expect(snapshot.status).toBe('ready')
    expect(snapshot.profile).toEqual({
      userId: expect.stringMatching(/^mock-self-/),
      username: 'ben.yks',
      inviteCode: expect.stringMatching(INVITE_CODE),
      isDiscoverable: true,
    })
    expect(snapshot.friends.map((f) => f.username)).toEqual(['elif.say', 'mert_ayt'])
    expect(snapshot.friends[0]).toEqual({
      userId: ELIF,
      username: 'elif.say',
      friendsSince: NOW.toISOString(),
      presence: {
        state: 'focusing',
        sessionStartedAt: new Date(NOW.getTime() - 70 * MINUTE).toISOString(),
        stateSince: new Date(NOW.getTime() - 25 * MINUTE).toISOString(),
        todayFocusMs: 130 * MINUTE,
        updatedAt: NOW.toISOString(),
      },
    })
    expect(snapshot.requests).toEqual([
      {
        id: expect.any(String),
        direction: 'incoming',
        user: { userId: ZEYNEP, username: 'zeynep2027' },
        createdAt: NOW.toISOString(),
      },
    ])
  })

  it('later claims only rename and keep the social graph', async () => {
    const { service } = await readySetup()
    const before = service.getSnapshot()

    const profile = await service.claimUsername('Yeni_Ad')

    expect(profile).toEqual({ ...before.profile, username: 'yeni_ad' })
    expect(service.getSnapshot().friends).toHaveLength(2)
    expect(service.getSnapshot().requests).toHaveLength(1)
    expect(await service.claimUsername('yeni_ad')).toEqual(profile)
  })

  it('persists the account per Apple user and reloads it', async () => {
    const { service } = await readySetup()
    const profile = service.getSnapshot().profile

    const reloaded = setup()
    reloaded.auth.session = SESSION
    await reloaded.service.refresh()
    expect(reloaded.service.getSnapshot().profile).toEqual(profile)

    reloaded.auth.session = { ...SESSION, appleUserId: 'mock-apple-2' }
    await reloaded.service.refresh()
    expect(reloaded.service.getSnapshot().status).toBe('needsUsername')
  })

  it('treats corrupt stored data as empty without throwing', async () => {
    for (const raw of ['{bozuk', '42', '{"version":2,"accounts":{}}', '{"version":1}']) {
      localStorage.setItem(SOCIAL_MOCK_STORAGE_KEY, raw)
      const { service, auth } = setup()
      auth.session = SESSION
      await service.refresh()
      expect(service.getSnapshot().status).toBe('needsUsername')
    }
  })

  it('reloads the account when the session changes between calls', async () => {
    const { service, auth } = await readySetup()

    auth.session = null
    await expectSocialError(service.setDiscoverable(false), 'notSignedIn')
    expect(service.getSnapshot().status).toBe('signedOut')

    auth.session = { ...SESSION, appleUserId: 'mock-apple-2' }
    await expectSocialError(service.setDiscoverable(false), 'noProfile')
    expect(service.getSnapshot().status).toBe('needsUsername')
  })
})

describe('MockSocialService — yerel veri (dışa aktarma / silme)', () => {
  it('exports the stored social data of this device', async () => {
    const { service } = await readySetup()

    const exported = await service.exportLocalData()

    expect(exported.accounts[SESSION.appleUserId]?.profile.username).toBe('ben.yks')
  })

  it('exports an empty document when nothing is stored', async () => {
    const { service } = setup()

    await expect(service.exportLocalData()).resolves.toEqual({ version: 1, accounts: {} })
  })

  it('clears stored social data and drops the in-memory profile', async () => {
    const { service } = await readySetup()

    await service.clearLocalData()

    expect(localStorage.getItem(SOCIAL_MOCK_STORAGE_KEY)).toBeNull()
    expect(service.getSnapshot()).toMatchObject({ status: 'needsUsername', profile: null })
    expect(service.getSnapshot().friends).toEqual([])
  })
})

describe('MockSocialService — abonelik ve değişmezlik', () => {
  it('returns the same snapshot until something changes and never mutates old ones', async () => {
    const { service } = await readySetup()
    const before = service.getSnapshot()
    const friendsBefore = before.friends
    expect(service.getSnapshot()).toBe(before)

    await service.removeFriend(MERT)

    const after = service.getSnapshot()
    expect(after).not.toBe(before)
    expect(before.friends).toBe(friendsBefore)
    expect(before.friends).toHaveLength(2)
    expect(after.friends).toHaveLength(1)
  })

  it('notifies subscribers until they unsubscribe', async () => {
    const { service, auth } = setup()
    const listener = vi.fn()
    const unsubscribe = service.subscribe(listener)
    auth.session = SESSION

    await service.refresh()
    expect(listener).toHaveBeenCalledTimes(1)

    unsubscribe()
    unsubscribe()
    await service.claimUsername('ben.yks')
    expect(listener).toHaveBeenCalledTimes(1)
  })
})

describe('MockSocialService — arkadaşlık', () => {
  it('sends a request by username that the simulated user accepts after a delay', async () => {
    vi.useFakeTimers()
    const { service } = await readySetup({ responseDelayMs: 1500 })

    const request = await service.sendFriendRequest({ kind: 'username', username: '@Deniz_EA' })

    expect(request).toEqual({
      id: expect.any(String),
      direction: 'outgoing',
      user: { userId: DENIZ, username: 'deniz_ea' },
      createdAt: NOW.toISOString(),
    })
    expect(service.getSnapshot().requests[0]).toEqual(request)

    await vi.advanceTimersByTimeAsync(1500)

    const snapshot = service.getSnapshot()
    expect(snapshot.requests.map((r) => r.id)).not.toContain(request.id)
    expect(snapshot.friends.map((f) => f.username)).toEqual(['deniz_ea', 'elif.say', 'mert_ayt'])
  })

  it('accepts immediately when responseDelayMs is 0 (lookup by invite code)', async () => {
    const { service } = await readySetup()

    await service.sendFriendRequest({ kind: 'inviteCode', code: 'can-tyt' })

    expect(service.getSnapshot().friends.map((f) => f.userId)).toContain(CAN)
    expect(service.getSnapshot().requests.every((r) => r.direction === 'incoming')).toBe(true)
  })

  it.each([
    [{ kind: 'username', username: 'x' }, 'invalidUsername'],
    [{ kind: 'inviteCode', code: 'ABC' }, 'invalidInviteCode'],
    [{ kind: 'username', username: 'kimse_yok' }, 'userNotFound'],
    [{ kind: 'inviteCode', code: 'ZZZZZZ' }, 'userNotFound'],
    [{ kind: 'username', username: 'Ben.YKS' }, 'self'],
    [{ kind: 'username', username: 'elif.say' }, 'alreadyFriends'],
    [{ kind: 'inviteCode', code: 'MERT27' }, 'alreadyFriends'],
    [{ kind: 'username', username: 'zeynep2027' }, 'requestExists'],
  ] as const)('sendFriendRequest(%o) → %s', async (lookup, code) => {
    const { service } = await readySetup()
    await expectSocialError(service.sendFriendRequest(lookup), code)
  })

  it('rejects my own invite code and a duplicate outgoing request', async () => {
    const { service } = await readySetup({ responseDelayMs: 1000 })
    const own = service.getSnapshot().profile?.inviteCode ?? ''
    await expectSocialError(service.sendFriendRequest({ kind: 'inviteCode', code: own }), 'self')

    await service.sendFriendRequest({ kind: 'username', username: 'ece_dil' })
    await expectSocialError(
      service.sendFriendRequest({ kind: 'inviteCode', code: 'ECEDIL' }),
      'requestExists',
    )
  })

  it('accepts or declines incoming requests', async () => {
    const { service } = await readySetup()
    const [incoming] = service.getSnapshot().requests

    await service.respondToRequest(incoming?.id ?? '', true)

    expect(service.getSnapshot().requests).toEqual([])
    expect(service.getSnapshot().friends.find((f) => f.userId === ZEYNEP)).toMatchObject({
      username: 'zeynep2027',
      friendsSince: NOW.toISOString(),
    })
  })

  it('declining removes the request without adding a friend', async () => {
    const { service } = await readySetup()
    const [incoming] = service.getSnapshot().requests

    await service.respondToRequest(incoming?.id ?? '', false)

    expect(service.getSnapshot().requests).toEqual([])
    expect(service.getSnapshot().friends).toHaveLength(2)
  })

  it('cancelRequest withdraws an outgoing request and its pending acceptance', async () => {
    vi.useFakeTimers()
    const { service } = await readySetup({ responseDelayMs: 1500 })
    const request = await service.sendFriendRequest({ kind: 'username', username: 'ece_dil' })

    await service.cancelRequest(request.id)
    await vi.advanceTimersByTimeAsync(5000)

    expect(service.getSnapshot().requests.map((r) => r.id)).not.toContain(request.id)
    expect(service.getSnapshot().friends.map((f) => f.userId)).not.toContain(ECE)
  })

  it('respond/cancel only accept the matching direction', async () => {
    const { service } = await readySetup({ responseDelayMs: 1000 })
    const incoming = service.getSnapshot().requests[0]?.id ?? ''
    const outgoing = (await service.sendFriendRequest({ kind: 'username', username: 'ece_dil' })).id

    await expectSocialError(service.respondToRequest('yok', true), 'requestNotFound')
    await expectSocialError(service.respondToRequest(outgoing, true), 'requestNotFound')
    await expectSocialError(service.cancelRequest(incoming), 'requestNotFound')
  })

  it('removeFriend removes a friend and rejects unknown ids', async () => {
    const { service } = await readySetup()

    await service.removeFriend(ELIF)

    expect(service.getSnapshot().friends.map((f) => f.userId)).toEqual([MERT])
    await expectSocialError(service.removeFriend(ELIF), 'friendNotFound')
  })

  it('reschedules pending outgoing requests after a reload', async () => {
    const first = await readySetup({ responseDelayMs: 1000 })
    await first.service.sendFriendRequest({ kind: 'username', username: 'ece_dil' })
    first.service.dispose()

    const reloaded = setup()
    reloaded.auth.session = SESSION
    await reloaded.service.refresh()

    expect(reloaded.service.getSnapshot().friends.map((f) => f.userId)).toContain(ECE)
  })
})

describe('MockSocialService — odalar', () => {
  it("lists friends' rooms with member and focusing counts", async () => {
    const { service } = await readySetup()

    expect(service.getSnapshot().friendRooms).toEqual([
      {
        id: 'mock-room-sabah',
        name: 'Sabah kampı',
        host: { userId: ELIF, username: 'elif.say' },
        memberCount: 2,
        focusingCount: 1,
      },
    ])

    await service.sendFriendRequest({ kind: 'username', username: 'deniz_ea' })
    expect(service.getSnapshot().friendRooms.map((r) => r.id)).toEqual([
      'mock-room-sabah',
      'mock-room-tytmat',
    ])
  })

  it("joins a friend's room by id; host first, me last", async () => {
    const { service, advanceClock } = await readySetup()
    advanceClock(MINUTE)

    const room = await service.joinRoom({ kind: 'room', roomId: 'mock-room-sabah' })

    expect(room).toMatchObject({
      id: 'mock-room-sabah',
      name: 'Sabah kampı',
      hostUserId: ELIF,
      inviteCode: 'SABAH1',
      createdAt: new Date(NOW.getTime() - 70 * MINUTE).toISOString(),
    })
    expect(room.members.map((m) => [m.username, m.isHost, m.isSelf])).toEqual([
      ['elif.say', true, false],
      ['mert_ayt', false, false],
      ['ben.yks', false, true],
    ])
    expect(room.members[2]?.joinedAt).toBe(new Date(NOW.getTime() + MINUTE).toISOString())
    expect(room.members[0]?.presence?.state).toBe('focusing')
    expect(service.getSnapshot().room).toEqual(room)
    expect(service.getSnapshot().friendRooms).toEqual([])
  })

  it('joins by invite code, leaving the previous room; re-joining is a no-op', async () => {
    const { service } = await readySetup()
    await service.joinRoom({ kind: 'room', roomId: 'mock-room-sabah' })

    const room = await service.joinRoom({ kind: 'inviteCode', code: 'tyt mat' })

    expect(room.id).toBe('mock-room-tytmat')
    expect(room.members.map((m) => m.username)).toEqual(['deniz_ea', 'can.tyt', 'ben.yks'])
    expect(service.getSnapshot().friendRooms.map((r) => r.id)).toEqual(['mock-room-sabah'])
    expect(await service.joinRoom({ kind: 'room', roomId: 'mock-room-tytmat' })).toBe(room)
  })

  it.each([
    [{ kind: 'room', roomId: 'yok' }, 'roomNotFound'],
    [{ kind: 'inviteCode', code: 'XXXXXX' }, 'roomNotFound'],
    [{ kind: 'inviteCode', code: '12' }, 'invalidInviteCode'],
  ] as const)('joinRoom(%o) → %s', async (target, code) => {
    const { service } = await readySetup()
    await expectSocialError(service.joinRoom(target), code)
  })

  it('createRoom validates the name and hosts a new room', async () => {
    const { service } = await readySetup({ responseDelayMs: 1000 })
    await expectSocialError(service.createRoom('   '), 'invalidRoomName')
    await expectSocialError(
      service.createRoom('a'.repeat(ROOM_NAME_MAX_LENGTH + 1)),
      'invalidRoomName',
    )

    const room = await service.createRoom('  Gece  çalışması ')

    const profile = service.getSnapshot().profile
    expect(room).toEqual({
      id: expect.any(String),
      name: 'Gece  çalışması',
      hostUserId: profile?.userId,
      inviteCode: expect.stringMatching(INVITE_CODE),
      createdAt: NOW.toISOString(),
      members: [
        {
          userId: profile?.userId,
          username: 'ben.yks',
          isSelf: true,
          isHost: true,
          presence: null,
          joinedAt: NOW.toISOString(),
        },
      ],
    })
    expect(room.inviteCode).not.toBe(profile?.inviteCode)
    expect(await service.joinRoom({ kind: 'inviteCode', code: room.inviteCode })).toBe(room)
  })

  it('the first online friend joins my room after responseDelayMs', async () => {
    vi.useFakeTimers()
    const { service } = await readySetup({ responseDelayMs: 1500 })
    const room = await service.createRoom('Gece')
    expect(room.members).toHaveLength(1)

    await vi.advanceTimersByTimeAsync(1500)

    const members = service.getSnapshot().room?.members ?? []
    expect(members.map((m) => [m.username, m.isHost])).toEqual([
      ['ben.yks', true],
      ['elif.say', false],
    ])
  })

  it('a reload reschedules the guest join for my still-empty hosted room', async () => {
    vi.useFakeTimers()
    const { service } = await readySetup({ responseDelayMs: 1500 })
    await service.createRoom('Gece')
    service.dispose()

    const reloaded = setup({ responseDelayMs: 1500 })
    reloaded.auth.session = SESSION
    await reloaded.service.refresh()
    expect(reloaded.service.getSnapshot().room?.members).toHaveLength(1)

    await vi.advanceTimersByTimeAsync(1500)

    expect(reloaded.service.getSnapshot().room?.members.map((m) => m.username)).toEqual([
      'ben.yks',
      'elif.say',
    ])
  })

  it('a friend joins immediately when responseDelayMs is 0', async () => {
    const { service } = await readySetup()
    await service.removeFriend(ELIF)

    const room = await service.createRoom('Gece')

    expect(room.members.map((m) => m.username)).toEqual(['ben.yks', 'mert_ayt'])
  })

  it('nobody joins when all friends are offline (stale presence)', async () => {
    const { service, advanceClock } = await readySetup()
    advanceClock(11 * MINUTE)

    const room = await service.createRoom('Gece')

    expect(room.members).toHaveLength(1)
  })

  it('leaving my hosted room closes it and cancels the pending guest', async () => {
    vi.useFakeTimers()
    const { service } = await readySetup({ responseDelayMs: 1500 })
    await service.createRoom('Gece')

    await service.leaveRoom()
    await vi.advanceTimersByTimeAsync(1500)

    expect(service.getSnapshot().room).toBeNull()
  })

  it('switching rooms cancels the pending guest of my previous room', async () => {
    vi.useFakeTimers()
    const { service } = await readySetup({ responseDelayMs: 1500 })
    await service.createRoom('Gece')

    await service.createRoom('Sabah')
    await vi.advanceTimersByTimeAsync(1500)

    const room = service.getSnapshot().room
    expect(room?.name).toBe('Sabah')
    expect(room?.members.map((m) => m.username)).toEqual(['ben.yks', 'elif.say'])
  })

  it('leaving a joined room removes me; leaveRoom is a no-op without a room or session', async () => {
    const { service, auth } = await readySetup()
    await service.joinRoom({ kind: 'room', roomId: 'mock-room-sabah' })

    await service.leaveRoom()
    expect(service.getSnapshot().room).toBeNull()
    expect(service.getSnapshot().friendRooms).toHaveLength(1)

    const before = service.getSnapshot()
    await service.leaveRoom()
    expect(service.getSnapshot()).toBe(before)

    auth.session = null
    await expect(service.leaveRoom()).resolves.toBeUndefined()
  })

  it('persists room membership across reloads', async () => {
    const { service } = await readySetup()
    await service.joinRoom({ kind: 'room', roomId: 'mock-room-tytmat' })

    const reloaded = setup()
    reloaded.auth.session = SESSION
    await reloaded.service.refresh()

    expect(reloaded.service.getSnapshot().room?.id).toBe('mock-room-tytmat')
  })
})

describe('MockSocialService — kendi durumum', () => {
  it('publishPresence shows up on my room member row and is persisted', async () => {
    const { service } = await readySetup()
    await service.joinRoom({ kind: 'room', roomId: 'mock-room-sabah' })
    const mine = presence()

    await service.publishPresence(mine)

    const self = service.getSnapshot().room?.members.find((m) => m.isSelf)
    expect(self?.presence).toEqual(mine)
    expect(localStorage.getItem(SOCIAL_MOCK_STORAGE_KEY)).toContain('"selfPresence":{')
  })

  it('publishing outside a room stores the presence without a new snapshot', async () => {
    const { service } = await readySetup()
    const before = service.getSnapshot()

    await service.publishPresence(presence())
    expect(service.getSnapshot()).toBe(before)

    const room = await service.joinRoom({ kind: 'room', roomId: 'mock-room-sabah' })
    expect(room.members.find((m) => m.isSelf)?.presence).toEqual(presence())
  })

  it('hidden users publish nothing; hiding clears the published presence', async () => {
    const { service } = await readySetup()
    await service.joinRoom({ kind: 'room', roomId: 'mock-room-sabah' })
    await service.publishPresence(presence())

    await service.setDiscoverable(false)

    const selfRow = () => service.getSnapshot().room?.members.find((m) => m.isSelf)
    expect(service.getSnapshot().profile?.isDiscoverable).toBe(false)
    expect(selfRow()?.presence).toBeNull()

    await service.publishPresence(presence())
    expect(selfRow()?.presence).toBeNull()

    await service.setDiscoverable(true)
    await service.publishPresence(presence({ state: 'onBreak' }))
    expect(selfRow()?.presence?.state).toBe('onBreak')
  })

  it.each([
    ['setDiscoverable', (s: MockSocialService) => s.setDiscoverable(true)],
    ['publishPresence', (s: MockSocialService) => s.publishPresence(presence())],
    [
      'sendFriendRequest',
      (s: MockSocialService) => s.sendFriendRequest({ kind: 'username', username: 'elif.say' }),
    ],
    ['respondToRequest', (s: MockSocialService) => s.respondToRequest('x', true)],
    ['cancelRequest', (s: MockSocialService) => s.cancelRequest('x')],
    ['removeFriend', (s: MockSocialService) => s.removeFriend('x')],
    ['createRoom', (s: MockSocialService) => s.createRoom('Oda')],
    ['joinRoom', (s: MockSocialService) => s.joinRoom({ kind: 'room', roomId: 'mock-room-sabah' })],
  ] as const)('%s requires a session and a profile', async (_name, call) => {
    const { service, auth } = setup()
    await expectSocialError(call(service), 'notSignedIn')
    auth.session = SESSION
    await expectSocialError(call(service), 'noProfile')
  })
})

describe('MockSocialService — simülasyon', () => {
  it('runs the simulation only while subscribed and tickMs > 0', async () => {
    vi.useFakeTimers()
    const { service } = await readySetup({ tickMs: 4000 })
    expect(vi.getTimerCount()).toBe(0)

    const unsubscribe = service.subscribe(vi.fn())
    expect(vi.getTimerCount()).toBe(1)
    unsubscribe()
    expect(vi.getTimerCount()).toBe(0)

    const noTicks = setup({ tickMs: 0 })
    noTicks.service.subscribe(vi.fn())
    expect(vi.getTimerCount()).toBe(0)
  })

  it('a tick applies transitions and heartbeats, then emits a new snapshot', async () => {
    vi.useFakeTimers()
    const { service, advanceClock, queueRandom } = await readySetup({ tickMs: 4000 })
    await service.respondToRequest(service.getSnapshot().requests[0]?.id ?? '', true)
    await service.sendFriendRequest({ kind: 'username', username: 'ece_dil' })
    const listener = vi.fn()
    service.subscribe(listener)
    const before = service.getSnapshot()
    // Sıra: elif, mert, zeynep, deniz, can, ece.
    queueRandom(0.01, 0.05, 0.021, 0.9, 0.9, 0.001)
    advanceClock(4000)

    await vi.advanceTimersByTimeAsync(4000)

    const tickAt = new Date(NOW.getTime() + 4000).toISOString()
    const byId = new Map(service.getSnapshot().friends.map((f) => [f.userId, f.presence]))
    expect(listener).toHaveBeenCalledTimes(1)
    expect(service.getSnapshot()).not.toBe(before)
    expect(byId.get(ELIF)).toMatchObject({
      state: 'onBreak',
      stateSince: tickAt,
      todayFocusMs: 130 * MINUTE + 4000,
      updatedAt: tickAt,
    })
    expect(byId.get(MERT)).toMatchObject({
      state: 'focusing',
      stateSince: tickAt,
      todayFocusMs: 65 * MINUTE,
    })
    expect(byId.get(ZEYNEP)).toMatchObject({
      state: 'offline',
      sessionStartedAt: null,
      stateSince: null,
      todayFocusMs: 40 * MINUTE + 4000,
    })
    expect(byId.get(ECE)).toMatchObject({
      state: 'focusing',
      sessionStartedAt: tickAt,
      stateSince: tickAt,
      todayFocusMs: 55 * MINUTE,
      updatedAt: tickAt,
    })
    expect(before.friends.find((f) => f.userId === ELIF)?.presence?.state).toBe('focusing')
  })

  it('catches up stale presences when the first subscriber arrives', async () => {
    vi.useFakeTimers()
    const { service, advanceClock } = await readySetup({ tickMs: 4000 })
    advanceClock(20 * MINUTE)

    service.subscribe(vi.fn())

    const elif = service.getSnapshot().friends.find((f) => f.userId === ELIF)
    expect(elif?.presence).toMatchObject({
      state: 'focusing',
      todayFocusMs: 150 * MINUTE,
      updatedAt: new Date(NOW.getTime() + 20 * MINUTE).toISOString(),
    })
  })

  it('does not emit ticks while signed out but keeps the world moving', async () => {
    vi.useFakeTimers()
    const { service } = setup({ tickMs: 1000 })
    await service.refresh()
    const listener = vi.fn()
    service.subscribe(listener)

    await vi.advanceTimersByTimeAsync(3000)

    expect(listener).not.toHaveBeenCalled()
  })
})
