/**
 * Web prototipi için sahte "Apple ile Giriş". Hiçbir ağ isteği yapmaz.
 * Oturum localStorage'da (`fokus.auth.session`) tutulur. Mock Apple kullanıcı kimliği
 * cihaz başına stabildir (`fokus.auth.mockAppleUserId`): çıkış yapıp tekrar girince aynı kalır,
 * tıpkı gerçek Apple kimliği gibi.
 */
import { newId } from '@/domain'
import {
  defaultStorage,
  safeGetItem,
  safeRemoveItem,
  safeSetItem,
  wait,
  type KeyValueStorage,
} from '../storage'
import type { AuthService, AuthSession } from './AuthService'

export const AUTH_SESSION_KEY = 'fokus.auth.session'
export const MOCK_APPLE_USER_ID_KEY = 'fokus.auth.mockAppleUserId'
const DEFAULT_DELAY_MS = 400

export interface MockAuthServiceOptions {
  /** Yapay gecikme (ms). Testlerde 0. */
  delayMs?: number
  /** Varsayılan: tarayıcı localStorage'ı (erişilemiyorsa yalnızca bellek içi davranış). */
  storage?: KeyValueStorage | null
}

const isNullableString = (value: unknown): value is string | null =>
  value === null || typeof value === 'string'

/** Saklanan JSON'u doğrular; bozuk/yabancı veri için null döner, asla fırlatmaz. */
export function parseAuthSession(raw: string | null): AuthSession | null {
  if (raw === null) return null
  let data: unknown
  try {
    data = JSON.parse(raw)
  } catch {
    return null
  }
  if (typeof data !== 'object' || data === null) return null
  const record = data as Record<string, unknown>
  const { appleUserId, displayName, email, isMock } = record
  if (typeof appleUserId !== 'string' || appleUserId.length === 0) return null
  if (!isNullableString(displayName) || !isNullableString(email)) return null
  if (typeof isMock !== 'boolean') return null
  return { appleUserId, displayName, email, isMock }
}

export class MockAuthService implements AuthService {
  private readonly storage: KeyValueStorage | null
  private readonly delayMs: number

  constructor(options: MockAuthServiceOptions = {}) {
    this.storage = options.storage === undefined ? defaultStorage() : options.storage
    this.delayMs = options.delayMs ?? DEFAULT_DELAY_MS
  }

  async getSession(): Promise<AuthSession | null> {
    return parseAuthSession(safeGetItem(this.storage, AUTH_SESSION_KEY))
  }

  async signInWithApple(): Promise<AuthSession> {
    await wait(this.delayMs)
    const session: AuthSession = {
      appleUserId: this.stableMockUserId(),
      displayName: null,
      email: null,
      isMock: true,
    }
    safeSetItem(this.storage, AUTH_SESSION_KEY, JSON.stringify(session))
    return session
  }

  async signOut(): Promise<void> {
    safeRemoveItem(this.storage, AUTH_SESSION_KEY)
  }

  /** Oturumu ve cihaza özel sahte Apple kimliğini siler; sonraki giriş yeni bir kimlik üretir. */
  async deleteAccount(): Promise<void> {
    await wait(this.delayMs)
    safeRemoveItem(this.storage, AUTH_SESSION_KEY)
    safeRemoveItem(this.storage, MOCK_APPLE_USER_ID_KEY)
  }

  private stableMockUserId(): string {
    const stored = safeGetItem(this.storage, MOCK_APPLE_USER_ID_KEY)
    if (stored?.startsWith('mock-apple-')) return stored
    const created = `mock-apple-${newId()}`
    safeSetItem(this.storage, MOCK_APPLE_USER_ID_KEY, created)
    return created
  }
}
