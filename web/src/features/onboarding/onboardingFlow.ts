/**
 * Onboarding adım makinesi — saf, React'tan bağımsız.
 * Hoş geldin → alan seçimi → hesap (Apple ile Giriş / Şimdilik atla).
 */
import type { YksField } from '@/domain'

export const ONBOARDING_STEPS = ['welcome', 'field', 'account'] as const

export type OnboardingStep = (typeof ONBOARDING_STEPS)[number]

export interface OnboardingState {
  step: OnboardingStep
  field: YksField | null
}

export type OnboardingAction =
  { type: 'next' } | { type: 'back' } | { type: 'selectField'; field: YksField }

export const initialOnboardingState: OnboardingState = { step: 'welcome', field: null }

/** Bir sonraki adıma geçilebilir mi? Alan seçilmeden hesap adımına geçilmez. */
export function canAdvance(state: OnboardingState): boolean {
  if (state.step === 'field') return state.field !== null
  return state.step !== 'account'
}

function shiftStep(step: OnboardingStep, delta: 1 | -1): OnboardingStep {
  const index = ONBOARDING_STEPS.indexOf(step) + delta
  return ONBOARDING_STEPS[Math.min(Math.max(index, 0), ONBOARDING_STEPS.length - 1)] ?? step
}

export function onboardingReducer(
  state: OnboardingState,
  action: OnboardingAction,
): OnboardingState {
  switch (action.type) {
    case 'selectField':
      return { ...state, field: action.field }
    case 'next':
      return canAdvance(state) ? { ...state, step: shiftStep(state.step, 1) } : state
    case 'back':
      return { ...state, step: shiftStep(state.step, -1) }
  }
}

/** 1 tabanlı adım numarası (ör. "Adım 2 / 3"). */
export function stepNumber(step: OnboardingStep): number {
  return ONBOARDING_STEPS.indexOf(step) + 1
}
