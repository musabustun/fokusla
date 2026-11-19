import { describe, expect, it } from 'vitest'
import {
  canAdvance,
  initialOnboardingState,
  onboardingReducer,
  stepNumber,
  type OnboardingState,
} from './onboardingFlow'

describe('onboardingReducer', () => {
  it('hoş geldin adımından alan seçimine geçer', () => {
    const next = onboardingReducer(initialOnboardingState, { type: 'next' })
    expect(next.step).toBe('field')
  })

  it('alan seçilmeden hesap adımına geçmez', () => {
    const state: OnboardingState = { step: 'field', field: null }
    expect(canAdvance(state)).toBe(false)
    expect(onboardingReducer(state, { type: 'next' })).toBe(state)
  })

  it('alan seçildikten sonra hesap adımına geçer', () => {
    const selected = onboardingReducer(
      { step: 'field', field: null },
      {
        type: 'selectField',
        field: 'EA',
      },
    )
    expect(selected.field).toBe('EA')
    expect(onboardingReducer(selected, { type: 'next' }).step).toBe('account')
  })

  it('son adımda ileri gitmez, ilk adımda geri gitmez', () => {
    const last: OnboardingState = { step: 'account', field: 'SAY' }
    expect(onboardingReducer(last, { type: 'next' })).toBe(last)
    expect(onboardingReducer(initialOnboardingState, { type: 'back' }).step).toBe('welcome')
  })

  it('geri gidince seçilen alanı korur', () => {
    const back = onboardingReducer({ step: 'account', field: 'DIL' }, { type: 'back' })
    expect(back).toEqual({ step: 'field', field: 'DIL' })
  })

  it('girdi durumunu değiştirmez', () => {
    const state: OnboardingState = { step: 'field', field: null }
    onboardingReducer(state, { type: 'selectField', field: 'SOZ' })
    expect(state.field).toBeNull()
  })

  it('adım numarasını 1 tabanlı verir', () => {
    expect(stepNumber('welcome')).toBe(1)
    expect(stepNumber('account')).toBe(3)
  })
})
