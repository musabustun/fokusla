/**
 * Bellek içi sahte senkron servisi. HİÇBİR AĞ G/Ç'si YAPMAZ; yalnızca CloudKit senkronunun
 * durum makinesini taklit eder:
 *
 *   disabled ──enable──▶ idle ──syncNow──▶ syncing ──▶ idle(lastSyncedAt)
 *       ▲                 │
 *       └────disable──────┘
 *
 * Değişiklikler senkron kapalıyken de kuyruğa alınır (açılınca hepsi "gönderilir");
 * aynı varlık+id için yalnızca en son değişiklik tutulur.
 */
import { toISODateTime } from '@/domain'
import { defaultStorage, safeGetItem, safeSetItem, wait, type KeyValueStorage } from '../storage'
import type { LocalChange, SyncService, SyncState } from './SyncService'

export const SYNC_ENABLED_KEY = 'fokus.sync.enabled'
const DEFAULT_SYNC_DELAY_MS = 600

export interface MockSyncServiceOptions {
  /** syncNow'un "syncing" durumunda kalma süresi (ms). Testlerde 0. */
  delayMs?: number
  storage?: KeyValueStorage | null
  now?: () => Date
}

type Listener = (state: SyncState) => void

const changeKey = (change: LocalChange): string => `${change.entity}:${change.id}`

export class MockSyncService implements SyncService {
  private readonly storage: KeyValueStorage | null
  private readonly delayMs: number
  private readonly now: () => Date
  private state: SyncState
  private queue: ReadonlyMap<string, LocalChange> = new Map()
  private listeners: ReadonlySet<Listener> = new Set()

  constructor(options: MockSyncServiceOptions = {}) {
    this.storage = options.storage === undefined ? defaultStorage() : options.storage
    this.delayMs = options.delayMs ?? DEFAULT_SYNC_DELAY_MS
    this.now = options.now ?? (() => new Date())
    const enabled = safeGetItem(this.storage, SYNC_ENABLED_KEY) === 'true'
    this.state = enabled ? { kind: 'idle', lastSyncedAt: null } : { kind: 'disabled' }
  }

  /** Değişene kadar aynı nesneyi döner (useSyncExternalStore için gerekli). */
  getState = (): SyncState => this.state

  subscribe = (listener: Listener): (() => void) => {
    this.listeners = new Set([...this.listeners, listener])
    return () => {
      this.listeners = new Set([...this.listeners].filter((l) => l !== listener))
    }
  }

  async enable(): Promise<void> {
    safeSetItem(this.storage, SYNC_ENABLED_KEY, 'true')
    if (this.state.kind === 'disabled') {
      this.setState({ kind: 'idle', lastSyncedAt: null })
    }
  }

  async disable(): Promise<void> {
    safeSetItem(this.storage, SYNC_ENABLED_KEY, 'false')
    if (this.state.kind !== 'disabled') {
      this.setState({ kind: 'disabled' })
    }
  }

  /** Kapalıyken veya zaten senkron sürerken hiçbir şey yapmaz. */
  async syncNow(): Promise<void> {
    if (this.state.kind === 'disabled' || this.state.kind === 'syncing') return
    const snapshot = this.queue
    this.setState({ kind: 'syncing' })
    await wait(this.delayMs)
    // Senkron sırasında kapatıldıysa sonucu yazma.
    if (this.getState().kind !== 'syncing') return
    // Yalnızca gönderilen kayıtları düş; senkron sırasında gelen yeni değişiklikler kalır.
    this.queue = new Map([...this.queue].filter(([key, change]) => snapshot.get(key) !== change))
    this.setState({ kind: 'idle', lastSyncedAt: toISODateTime(this.now()) })
  }

  recordLocalChange = (change: LocalChange): void => {
    const next = new Map(this.queue)
    next.set(changeKey(change), { ...change })
    this.queue = next
  }

  pendingChangeCount(): number {
    return this.queue.size
  }

  /** Bekleyen değişikliklerin kopyası (test/debug için). */
  pendingChanges(): LocalChange[] {
    return [...this.queue.values()].map((change) => ({ ...change }))
  }

  private setState(next: SyncState): void {
    this.state = next
    for (const listener of this.listeners) listener(next)
  }
}
