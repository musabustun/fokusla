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
export type {
  FriendLookup,
  FriendRequest,
  FriendRequestDirection,
  RoomMember,
  RoomSummary,
  RoomTarget,
  SocialErrorCode,
  SocialFriend,
  SocialProfile,
  SocialRoom,
  SocialService,
  SocialSnapshot,
  SocialStatus,
  SocialUser,
  UsernameCheck,
} from './social/SocialService'
export { ROOM_NAME_MAX_LENGTH, SocialError } from './social/SocialService'
export { ServicesProvider, useServices } from './ServicesContext'
export { createServices, type CreateServicesOptions } from './createServices'
export { ensureCurriculumSeeded, type SeedResult } from './seed/ensureCurriculumSeeded'
export { useLiveData, useCurrentProfile, useSyncState, type CurrentProfileState } from './hooks'
export { MockAuthService, type MockAuthServiceOptions } from './auth/MockAuthService'
export { MockSyncService, type MockSyncServiceOptions } from './sync/MockSyncService'
export { MockSocialService, type MockSocialServiceOptions } from './social/MockSocialService'
