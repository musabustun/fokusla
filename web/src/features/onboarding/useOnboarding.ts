import { useReducer, useState, type Dispatch } from 'react'
import { useNavigate } from 'react-router'
import { ROUTES } from '@/app/routes'
import { AuthCancelledError, useServices, type AuthSession } from '@/data'
import { completeOnboarding } from './completeOnboarding'
import {
  initialOnboardingState,
  onboardingReducer,
  type OnboardingAction,
  type OnboardingState,
} from './onboardingFlow'

export type AccountChoice = 'apple' | 'skip'

export interface UseOnboardingResult {
  state: OnboardingState
  dispatch: Dispatch<OnboardingAction>
  /** Şu an işlenen seçim (buton yükleniyor durumu için). */
  pending: AccountChoice | null
  error: string | null
  finish: (choice: AccountChoice) => Promise<void>
}

const GENERIC_ERROR = 'Bir şeyler ters gitti. Lütfen tekrar dene.'

/** Onboarding ekranının durum ve yan etkileri (giriş, profil kaydı, yönlendirme). */
export function useOnboarding(): UseOnboardingResult {
  const { auth, repositories } = useServices()
  const navigate = useNavigate()
  const [state, dispatch] = useReducer(onboardingReducer, initialOnboardingState)
  const [pending, setPending] = useState<AccountChoice | null>(null)
  const [error, setError] = useState<string | null>(null)

  async function finish(choice: AccountChoice): Promise<void> {
    if (!state.field || pending) return
    setPending(choice)
    setError(null)
    try {
      const session: AuthSession | null = choice === 'apple' ? await auth.signInWithApple() : null
      await completeOnboarding(repositories, { field: state.field, session })
      await navigate(ROUTES.today, { replace: true })
    } catch (caught: unknown) {
      if (!(caught instanceof AuthCancelledError)) {
        console.error('Onboarding tamamlanamadı', caught)
        setError(GENERIC_ERROR)
      }
      setPending(null)
    }
  }

  return { state, dispatch, pending, error, finish }
}
