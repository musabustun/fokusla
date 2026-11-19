/**
 * Veri katmanının PUBLIC API'si. Feature'lar ve app yalnızca buradan import eder:
 *   import { useServices, type Repositories } from '@/data'
 */
export type * from './repository'
export { EntityNotFoundError } from './repository'
export type { AppServices } from './services'
export { DATA_EXPORT_FORMAT_VERSION, type DataExport, type LocalDataService } from './localData'
export type { AuthService, AuthSession } from './auth/AuthService'
export { AuthCancelledError } from './auth/AuthService'
export type { LocalChange, SyncService, SyncState } from './sync/SyncService'
export { ServicesProvider, useServices } from './ServicesContext'
export { createServices, type CreateServicesOptions } from './createServices'
export { ensureCurriculumSeeded, type SeedResult } from './seed/ensureCurriculumSeeded'
export { useLiveData, useCurrentProfile, useSyncState, type CurrentProfileState } from './hooks'
export { MockAuthService, type MockAuthServiceOptions } from './auth/MockAuthService'
export { MockSyncService, type MockSyncServiceOptions } from './sync/MockSyncService'
