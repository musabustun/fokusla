/**
 * Web prototipi için sahte sosyal servis. HİÇBİR AĞ G/Ç'si YAPMAZ.
 *
 *  - Profil, arkadaşlar, istekler, oda ve son yayınlanan kendi durumum localStorage'da
 *    (`fokus.social.mock.v1`), Apple kullanıcı kimliği başına saklanır.
 *  - Arkadaşlar ve odalardaki diğer kişiler `simulatedUsers.ts`'teki sabit dünyadan gelir;
 *    canlı durumları saklanmaz, `now`'dan üretilir ve abone varken zamanlayıcıyla ilerletilir.
 *  - Simüle kullanıcılar arkadaşlık isteğini `responseDelayMs` sonra kabul eder; açtığım odaya
 *    çevrimiçi ilk arkadaş `responseDelayMs` sonra katılır (0 → çağrı çözülmeden hemen).
 */
import { effectivePresenceState, normalizeInviteCode, validateUsername } from '@/domain/calc/social'
import { newId, toISODateTime, type SocialPresence } from '@/domain'
import type { AuthService } from '../auth/AuthService'
import { defaultStorage, wait, type KeyValueStorage } from '../storage'
import { buildSnapshot, emptySnapshot, sortFriends, type PresenceMap } from './mockSocialSnapshot'
import {
  readAccount,
  writeAccount,
  type StoredAccount,
  type StoredFriend,
  type StoredRoom,
} from './mockSocialStore'
import {
  findSimulatedUserById,
  findSimulatedUserByInviteCode,
  findSimulatedUserByUsername,
  heartbeat,
  initialPresence,
  RESERVED_USERNAMES,
  SEED_FRIEND_USERNAMES,
  SEED_INCOMING_REQUEST_USERNAMES,
  SIMULATED_ROOMS,
  SIMULATED_USERS,
  simulatePresence,
  type SimulatedRoom,
  type SimulatedUser,
} from './simulatedUsers'
import {
  ROOM_NAME_MAX_LENGTH,
  SocialError,
  type FriendLookup,
  type FriendRequest,
  type RoomTarget,
  type SocialProfile,
  type SocialRoom,
  type SocialService,
  type SocialSnapshot,
  type SocialStatus,
  type UsernameCheck,
} from './SocialService'

const DEFAULT_DELAY_MS = 250
const DEFAULT_TICK_MS = 4000
const DEFAULT_RESPONSE_DELAY_MS = 1500
const INVITE_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
const INVITE_CODE_LENGTH = 6
const MAX_INVITE_CODE_ATTEMPTS = 50

export interface MockSocialServiceOptions {
  auth: AuthService
  /** Varsayılan: tarayıcı localStorage'ı (erişilemiyorsa yalnızca bellek içi). */
  storage?: KeyValueStorage | null
  now?: () => Date
  /** 0 ≤ r < 1; testlerde tohumlanmış bir üreteç verilir. */
  random?: () => number
  /** Her async çağrının yapay gecikmesi (ms). Testlerde 0. */
  delayMs?: number
  /** Simülasyon adımı (ms). 0 → zamanlayıcı hiç kurulmaz. */
  tickMs?: number
  /** Simüle arkadaşın isteği kabul etmesi / odama katılması için gecikme (ms). 0 → hemen. */
  responseDelayMs?: number
}

type Listener = () => void
type Timer = ReturnType<typeof setTimeout>

const requestTimerKey = (requestId: string) => `request:${requestId}`
const roomTimerKey = (roomId: string) => `room:${roomId}`

const userOf = (simulated: SimulatedUser) => ({
  userId: simulated.userId,
  username: simulated.username,
})

export class MockSocialService implements SocialService {
  private readonly auth: AuthService
  private readonly storage: KeyValueStorage | null
  private readonly now: () => Date
  private readonly random: () => number
  private readonly delayMs: number
  private readonly tickMs: number
  private readonly responseDelayMs: number
  private readonly worldStartedAt: Date

  private presences: PresenceMap
  private status: SocialStatus = 'loading'
  private appleUserId: string | null = null
  private account: StoredAccount | null = null
  private snapshot: SocialSnapshot = emptySnapshot('loading')
  private listeners: ReadonlySet<Listener> = new Set()
  private simulationTimer: ReturnType<typeof setInterval> | null = null
  private responseTimers: ReadonlyMap<string, Timer> = new Map()

  constructor(options: MockSocialServiceOptions) {
    this.auth = options.auth
    this.storage = options.storage === undefined ? defaultStorage() : options.storage
    this.now = options.now ?? (() => new Date())
    this.random = options.random ?? Math.random
    this.delayMs = options.delayMs ?? DEFAULT_DELAY_MS
    this.tickMs = options.tickMs ?? DEFAULT_TICK_MS
    this.responseDelayMs = options.responseDelayMs ?? DEFAULT_RESPONSE_DELAY_MS
    this.worldStartedAt = this.now()
    this.presences = new Map(
      SIMULATED_USERS.map((u) => [u.userId, initialPresence(u, this.worldStartedAt)]),
    )
  }

  // -------------------------------------------------------------------------
  // Abonelik
  // -------------------------------------------------------------------------

  getSnapshot = (): SocialSnapshot => this.snapshot

  subscribe = (listener: Listener): (() => void) => {
    this.listeners = new Set([...this.listeners, listener])
    this.startSimulation()
    return () => {
      this.listeners = new Set([...this.listeners].filter((l) => l !== listener))
      if (this.listeners.size === 0) this.stopSimulation()
    }
  }

  /** Tüm zamanlayıcıları durdurur (testler / servis kapatılırken). */
  dispose(): void {
    this.stopSimulation()
    for (const timer of this.responseTimers.values()) clearTimeout(timer)
    this.responseTimers = new Map()
  }

  // -------------------------------------------------------------------------
  // Oturum ve profil
  // -------------------------------------------------------------------------

  async refresh(): Promise<void> {
    await wait(this.delayMs)
    const session = await this.auth.getSession()
    this.load(session?.appleUserId ?? null)
  }

  async checkUsername(raw: string): Promise<UsernameCheck> {
    await wait(this.delayMs)
    const validation = validateUsername(raw)
    if (!validation.ok) return validation
    if (this.isUsernameTaken(validation.username)) return { ok: false, problem: 'taken' }
    return { ok: true, username: validation.username }
  }

  async claimUsername(raw: string): Promise<SocialProfile> {
    await wait(this.delayMs)
    const appleUserId = await this.requireSession()
    const validation = validateUsername(raw)
    if (!validation.ok) throw new SocialError('invalidUsername')
    const { username } = validation
    if (this.isUsernameTaken(username)) throw new SocialError('usernameTaken')

    const current = this.account
    if (current) {
      if (current.profile.username !== username) {
        this.updateAccount({ ...current, profile: { ...current.profile, username } })
      }
    } else {
      this.account = this.seedAccount(username)
      this.status = 'ready'
      writeAccount(this.storage, appleUserId, this.account)
      this.commit()
    }
    return this.requireAccount().profile
  }

  async setDiscoverable(isDiscoverable: boolean): Promise<void> {
    await wait(this.delayMs)
    const account = await this.requireProfile()
    this.updateAccount({
      ...account,
      profile: { ...account.profile, isDiscoverable },
      selfPresence: isDiscoverable ? account.selfPresence : null,
    })
  }

  async publishPresence(presence: SocialPresence): Promise<void> {
    await wait(this.delayMs)
    const account = await this.requireProfile()
    const selfPresence = account.profile.isDiscoverable ? { ...presence } : null
    // Odada değilsem anlık görüntü değişmez: yalnızca sakla, yayın yapma.
    this.updateAccount({ ...account, selfPresence }, { emit: account.room !== null })
  }

  // -------------------------------------------------------------------------
  // Arkadaşlık
  // -------------------------------------------------------------------------

  async sendFriendRequest(lookup: FriendLookup): Promise<FriendRequest> {
    await wait(this.delayMs)
    const account = await this.requireProfile()
    const target = this.resolveFriendLookup(lookup, account.profile)
    if (account.friends.some((f) => f.userId === target.userId)) {
      throw new SocialError('alreadyFriends')
    }
    if (account.requests.some((r) => r.user.userId === target.userId)) {
      throw new SocialError('requestExists')
    }
    const request: FriendRequest = {
      id: newId(),
      direction: 'outgoing',
      user: userOf(target),
      createdAt: toISODateTime(this.now()),
    }
    this.updateAccount({ ...account, requests: [request, ...account.requests] })
    this.scheduleAcceptance(request.id)
    return request
  }

  async respondToRequest(requestId: string, accept: boolean): Promise<void> {
    await wait(this.delayMs)
    const account = await this.requireProfile()
    const request = account.requests.find((r) => r.id === requestId && r.direction === 'incoming')
    if (!request) throw new SocialError('requestNotFound')
    this.updateAccount(this.resolveRequest(account, request, accept))
  }

  async cancelRequest(requestId: string): Promise<void> {
    await wait(this.delayMs)
    const account = await this.requireProfile()
    const request = account.requests.find((r) => r.id === requestId && r.direction === 'outgoing')
    if (!request) throw new SocialError('requestNotFound')
    this.clearResponseTimer(requestTimerKey(requestId))
    this.updateAccount(this.resolveRequest(account, request, false))
  }

  async removeFriend(userId: string): Promise<void> {
    await wait(this.delayMs)
    const account = await this.requireProfile()
    if (!account.friends.some((f) => f.userId === userId)) throw new SocialError('friendNotFound')
    this.updateAccount({ ...account, friends: account.friends.filter((f) => f.userId !== userId) })
  }

  // -------------------------------------------------------------------------
  // Odalar
  // -------------------------------------------------------------------------

  async createRoom(name: string): Promise<SocialRoom> {
    await wait(this.delayMs)
    const account = await this.requireProfile()
    const trimmed = name.trim()
    if (trimmed.length === 0 || trimmed.length > ROOM_NAME_MAX_LENGTH) {
      throw new SocialError('invalidRoomName')
    }
    this.clearRoomTimer(account.room)
    const room: StoredRoom = {
      kind: 'hosted',
      id: newId(),
      name: trimmed,
      inviteCode: this.generateInviteCode(),
      createdAt: toISODateTime(this.now()),
      guests: [],
    }
    this.updateAccount({ ...account, room })
    this.scheduleGuestJoin(room.id)
    return this.requireRoom()
  }

  async joinRoom(target: RoomTarget): Promise<SocialRoom> {
    await wait(this.delayMs)
    const account = await this.requireProfile()
    const resolved = this.resolveRoomTarget(target, this.snapshot.room)
    if (resolved === 'current') return this.requireRoom()

    this.clearRoomTimer(account.room)
    const room: StoredRoom = {
      kind: 'joined',
      roomId: resolved.id,
      joinedAt: toISODateTime(this.now()),
    }
    this.updateAccount({ ...account, room })
    return this.requireRoom()
  }

  async leaveRoom(): Promise<void> {
    await wait(this.delayMs)
    const session = await this.auth.getSession()
    this.syncSession(session?.appleUserId ?? null)
    const account = this.account
    if (!account?.room) return
    this.clearRoomTimer(account.room)
    this.updateAccount({ ...account, room: null })
  }

  // -------------------------------------------------------------------------
  // Durum yönetimi
  // -------------------------------------------------------------------------

  private load(appleUserId: string | null): void {
    for (const timer of this.responseTimers.values()) clearTimeout(timer)
    this.responseTimers = new Map()
    this.appleUserId = appleUserId
    this.account = appleUserId === null ? null : readAccount(this.storage, appleUserId)
    this.status = appleUserId === null ? 'signedOut' : this.account ? 'ready' : 'needsUsername'
    this.commit()
    // Yeniden yüklemeden önce bekleyen giden istekler yine kabul edilsin.
    for (const request of this.account?.requests ?? []) {
      if (request.direction === 'outgoing') this.scheduleAcceptance(request.id)
    }
    // Kendi odama henüz kimse katılmadıysa simüle edilen katılım da yeniden planlansın.
    const room = this.account?.room
    if (room?.kind === 'hosted' && room.guests.length === 0) this.scheduleGuestJoin(room.id)
  }

  /** Oturum başka bir kullanıcıya geçtiyse (ya da çıkıldıysa) hesabı yeniden yükler. */
  private syncSession(appleUserId: string | null): void {
    const changed = appleUserId !== this.appleUserId
    if (changed || (appleUserId === null && this.status !== 'signedOut')) this.load(appleUserId)
  }

  private async requireSession(): Promise<string> {
    const session = await this.auth.getSession()
    this.syncSession(session?.appleUserId ?? null)
    if (!session) throw new SocialError('notSignedIn')
    return session.appleUserId
  }

  private async requireProfile(): Promise<StoredAccount> {
    await this.requireSession()
    return this.requireAccount()
  }

  private requireAccount(): StoredAccount {
    if (!this.account) throw new SocialError('noProfile')
    return this.account
  }

  private requireRoom(): SocialRoom {
    const room = this.snapshot.room
    if (!room) throw new SocialError('roomNotFound')
    return room
  }

  /** Hesabı değiştirir, saklar ve (emit ise) yeni anlık görüntü yayınlar. */
  private updateAccount(next: StoredAccount, { emit = true }: { emit?: boolean } = {}): void {
    if (this.appleUserId === null) return
    this.account = next
    writeAccount(this.storage, this.appleUserId, next)
    if (emit) this.commit()
  }

  private commit(): void {
    this.snapshot = buildSnapshot({
      status: this.status,
      account: this.account,
      presences: this.presences,
      worldStartedAt: this.worldStartedAt,
      now: this.now(),
    })
    for (const listener of this.listeners) listener()
  }

  private seedAccount(username: string): StoredAccount {
    const nowIso = toISODateTime(this.now())
    const seedUsers = (names: readonly string[]) =>
      names.map(findSimulatedUserByUsername).filter((u): u is SimulatedUser => u !== undefined)
    const friends: StoredFriend[] = seedUsers(SEED_FRIEND_USERNAMES).map((u) => ({
      ...userOf(u),
      friendsSince: nowIso,
    }))
    const requests: FriendRequest[] = seedUsers(SEED_INCOMING_REQUEST_USERNAMES).map((u) => ({
      id: newId(),
      direction: 'incoming',
      user: userOf(u),
      createdAt: nowIso,
    }))
    return {
      profile: {
        userId: `mock-self-${newId()}`,
        username,
        inviteCode: this.generateInviteCode(),
        isDiscoverable: true,
      },
      friends,
      requests,
      room: null,
      selfPresence: null,
    }
  }

  private isUsernameTaken(username: string): boolean {
    if (username === this.account?.profile.username) return false
    return (
      RESERVED_USERNAMES.includes(username) || findSimulatedUserByUsername(username) !== undefined
    )
  }

  private resolveFriendLookup(lookup: FriendLookup, profile: SocialProfile): SimulatedUser {
    let found: SimulatedUser | undefined
    if (lookup.kind === 'username') {
      const validation = validateUsername(lookup.username)
      if (!validation.ok) throw new SocialError('invalidUsername')
      if (validation.username === profile.username) throw new SocialError('self')
      found = findSimulatedUserByUsername(validation.username)
    } else {
      const code = normalizeInviteCode(lookup.code)
      if (code === null) throw new SocialError('invalidInviteCode')
      if (code === profile.inviteCode) throw new SocialError('self')
      found = findSimulatedUserByInviteCode(code)
    }
    if (!found) throw new SocialError('userNotFound')
    return found
  }

  /** İsteği listeden çıkarır; accept ise kişiyi arkadaş ekler. */
  private resolveRequest(
    account: StoredAccount,
    request: FriendRequest,
    accept: boolean,
  ): StoredAccount {
    const requests = account.requests.filter((r) => r.id !== request.id)
    const isFriend = account.friends.some((f) => f.userId === request.user.userId)
    if (!accept || isFriend) return { ...account, requests }
    const friend: StoredFriend = { ...request.user, friendsSince: toISODateTime(this.now()) }
    return { ...account, requests, friends: [...account.friends, friend] }
  }

  /** 'current': hedef zaten içinde olduğum oda. */
  private resolveRoomTarget(
    target: RoomTarget,
    current: SocialRoom | null,
  ): SimulatedRoom | 'current' {
    if (target.kind === 'room') {
      if (current?.id === target.roomId) return 'current'
      const room = SIMULATED_ROOMS.find((r) => r.id === target.roomId)
      if (!room) throw new SocialError('roomNotFound')
      return room
    }
    const code = normalizeInviteCode(target.code)
    if (code === null) throw new SocialError('invalidInviteCode')
    if (current?.inviteCode === code) return 'current'
    const room = SIMULATED_ROOMS.find((r) => r.inviteCode === code)
    if (!room) throw new SocialError('roomNotFound')
    return room
  }

  private generateInviteCode(): string {
    const used = new Set([
      ...SIMULATED_USERS.map((u) => u.inviteCode),
      ...SIMULATED_ROOMS.map((r) => r.inviteCode),
      ...(this.account ? [this.account.profile.inviteCode] : []),
      ...(this.account?.room?.kind === 'hosted' ? [this.account.room.inviteCode] : []),
    ])
    const pick = () => {
      const index = Math.floor(this.random() * INVITE_CODE_ALPHABET.length)
      return INVITE_CODE_ALPHABET[Math.min(Math.max(index, 0), INVITE_CODE_ALPHABET.length - 1)]
    }
    let code = ''
    for (let attempt = 0; attempt < MAX_INVITE_CODE_ATTEMPTS; attempt += 1) {
      code = Array.from({ length: INVITE_CODE_LENGTH }, pick).join('')
      if (!used.has(code)) return code
    }
    return code
  }

  // -------------------------------------------------------------------------
  // Simüle yanıtlar
  // -------------------------------------------------------------------------

  private schedule(key: string, action: () => void): void {
    if (this.responseDelayMs <= 0) {
      action()
      return
    }
    this.clearResponseTimer(key)
    const timer = setTimeout(() => {
      this.responseTimers = new Map([...this.responseTimers].filter(([k]) => k !== key))
      action()
    }, this.responseDelayMs)
    this.responseTimers = new Map([...this.responseTimers, [key, timer]])
  }

  private clearResponseTimer(key: string): void {
    const timer = this.responseTimers.get(key)
    if (timer === undefined) return
    clearTimeout(timer)
    this.responseTimers = new Map([...this.responseTimers].filter(([k]) => k !== key))
  }

  private clearRoomTimer(room: StoredRoom | null): void {
    if (room?.kind === 'hosted') this.clearResponseTimer(roomTimerKey(room.id))
  }

  private scheduleAcceptance(requestId: string): void {
    this.schedule(requestTimerKey(requestId), () => {
      const account = this.account
      const request = account?.requests.find(
        (r) => r.id === requestId && r.direction === 'outgoing',
      )
      if (!account || !request) return
      this.updateAccount(this.resolveRequest(account, request, true))
    })
  }

  private scheduleGuestJoin(roomId: string): void {
    this.schedule(roomTimerKey(roomId), () => {
      const account = this.account
      const room = account?.room
      if (!account || room?.kind !== 'hosted' || room.id !== roomId) return
      const now = this.now()
      const guestIds = new Set(room.guests.map((g) => g.userId))
      const guest = sortFriends(account.friends).find(
        (f) =>
          !guestIds.has(f.userId) &&
          findSimulatedUserById(f.userId) !== undefined &&
          effectivePresenceState(this.presences.get(f.userId) ?? null, now) !== 'offline',
      )
      if (!guest) return
      const guests = [...room.guests, { userId: guest.userId, joinedAt: toISODateTime(now) }]
      this.updateAccount({ ...account, room: { ...room, guests } })
    })
  }

  // -------------------------------------------------------------------------
  // Simülasyon
  // -------------------------------------------------------------------------

  private startSimulation(): void {
    if (this.tickMs <= 0 || this.simulationTimer !== null) return
    // Abone yokken geçen süreyi yakala: durumlar bayatlayıp "çevrimdışı" görünmesin.
    const now = this.now()
    this.presences = new Map([...this.presences].map(([id, p]) => [id, heartbeat(p, now)]))
    if (this.status === 'ready') {
      this.snapshot = buildSnapshot({
        status: this.status,
        account: this.account,
        presences: this.presences,
        worldStartedAt: this.worldStartedAt,
        now,
      })
    }
    this.simulationTimer = setInterval(() => this.tick(), this.tickMs)
  }

  private stopSimulation(): void {
    if (this.simulationTimer === null) return
    clearInterval(this.simulationTimer)
    this.simulationTimer = null
  }

  /** Bir simülasyon adımı: her simüle kullanıcı için bir rastgele sayı (SIMULATED_USERS sırası). */
  private tick(): void {
    const now = this.now()
    this.presences = new Map(
      SIMULATED_USERS.map((u) => {
        const current = this.presences.get(u.userId) ?? initialPresence(u, now)
        return [u.userId, simulatePresence(current, this.random(), now)]
      }),
    )
    if (this.status === 'ready') this.commit()
  }
}
