import { Navigate, Outlet } from 'react-router'
import { ROUTES } from '@/app/routes'
import { useCurrentProfile } from '@/data'
import { isOnboarded } from './completeOnboarding'

/**
 * Uygulama rotalarını korur: profil okunana kadar boş bir yükleme durumu gösterir;
 * onboarding tamamlanmadıysa /hos-geldin'e yönlendirir.
 */
export function OnboardingGate() {
  const state = useCurrentProfile()
  if (state.status === 'loading') {
    return <div className="min-h-dvh bg-background" aria-busy="true" />
  }
  if (!isOnboarded(state.profile)) {
    return <Navigate to={ROUTES.onboarding} replace />
  }
  return <Outlet />
}
