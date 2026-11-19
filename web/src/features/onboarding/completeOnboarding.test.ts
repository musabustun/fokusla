import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import type { AppServices } from '@/data'
import { createTestServices, type TestServices } from '@/test/services'
import { completeOnboarding, isOnboarded } from './completeOnboarding'

const NOW = new Date('2026-11-19T08:00:00.000Z')
const SESSION = {
  appleUserId: 'mock-apple-1',
  displayName: 'Ada',
  email: null,
  isMock: true,
}

describe('completeOnboarding', () => {
  let ctx: TestServices
  let services: AppServices

  beforeEach(() => {
    ctx = createTestServices()
    services = ctx.services
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  it('giriş atlanınca Apple kimliği olmadan profil oluşturur', async () => {
    const profile = await completeOnboarding(
      services.repositories,
      { field: 'EA', session: null },
      NOW,
    )
    expect(profile).toMatchObject({
      field: 'EA',
      appleUserId: null,
      displayName: null,
      targetExamYear: null,
      onboardingCompletedAt: NOW.toISOString(),
    })
    expect(await services.repositories.profiles.getCurrent()).toEqual(profile)
  })

  it('Apple ile girişte oturum bilgisini profile yazar', async () => {
    const profile = await completeOnboarding(services.repositories, {
      field: 'SAY',
      session: SESSION,
    })
    expect(profile).toMatchObject({ appleUserId: 'mock-apple-1', displayName: 'Ada' })
  })

  it('mevcut profili kopyalamadan günceller ve Apple kimliğini korur', async () => {
    await completeOnboarding(services.repositories, { field: 'SAY', session: SESSION })
    const updated = await completeOnboarding(services.repositories, {
      field: 'DIL',
      session: null,
    })
    expect(updated).toMatchObject({ field: 'DIL', appleUserId: 'mock-apple-1' })
    expect(await services.repositories.profiles.findAll()).toHaveLength(1)
  })
})

describe('isOnboarded', () => {
  it('yalnızca onboardingCompletedAt doluysa true döner', () => {
    expect(isOnboarded(undefined)).toBe(false)
    const base = {
      id: '1',
      createdAt: '',
      updatedAt: '',
      deletedAt: null,
      displayName: null,
      field: 'SAY' as const,
      appleUserId: null,
      targetExamYear: null,
    }
    expect(isOnboarded({ ...base, onboardingCompletedAt: null })).toBe(false)
    expect(isOnboarded({ ...base, onboardingCompletedAt: '2026-11-19T08:00:00.000Z' })).toBe(true)
  })
})
