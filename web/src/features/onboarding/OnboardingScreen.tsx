import { Navigate } from 'react-router'
import { ROUTES } from '@/app/routes'
import { useCurrentProfile } from '@/data'
import { AccountStep } from './AccountStep'
import { FieldStep } from './FieldStep'
import { isOnboarded } from './completeOnboarding'
import { useOnboarding } from './useOnboarding'
import { WelcomeStep } from './WelcomeStep'

/** Hoş geldin → alan seçimi → Apple ile Giriş (mock) / Şimdilik atla → Bugün. */
export function OnboardingScreen() {
  const profileState = useCurrentProfile()
  const { state, dispatch, pending, error, finish } = useOnboarding()

  // Tamamlanmış bir profille buraya gelinirse (ör. geri tuşu) doğrudan uygulamaya dön.
  // Kendi tamamlama akışımız sürerken (pending) yönlendirmeyi useOnboarding yapar.
  if (profileState.status === 'ready' && isOnboarded(profileState.profile) && !pending) {
    return <Navigate to={ROUTES.today} replace />
  }

  const next = () => dispatch({ type: 'next' })
  const back = () => dispatch({ type: 'back' })

  switch (state.step) {
    case 'welcome':
      return <WelcomeStep onNext={next} />
    case 'field':
      return (
        <FieldStep
          value={state.field}
          onChange={(field) => dispatch({ type: 'selectField', field })}
          onNext={next}
          onBack={back}
        />
      )
    case 'account':
      return <AccountStep pending={pending} error={error} onChoose={finish} onBack={back} />
  }
}
