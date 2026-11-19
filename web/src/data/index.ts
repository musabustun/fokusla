/**
 * Veri katmanının PUBLIC API'si. Feature'lar ve app yalnızca buradan import eder:
 *   import { useServices, type Repositories } from '@/data'
 */
export type * from './repository'
export { EntityNotFoundError } from './repository'
export type { AppServices } from './services'
export type { AuthService, AuthSession } from './auth/AuthService'
export { AuthCancelledError } from './auth/AuthService'
export type { LocalChange, SyncService, SyncState } from './sync/SyncService'
export { ServicesProvider, useServices } from './ServicesContext'
export { createServices } from './createServices'
