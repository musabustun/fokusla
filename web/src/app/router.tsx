import { createBrowserRouter, type RouteObject } from 'react-router'
import { AnalysisScreen } from '@/features/analysis/AnalysisScreen'
import { BooksScreen } from '@/features/books/BooksScreen'
import { FocusScreen } from '@/features/focus/FocusScreen'
import { OnboardingGate } from '@/features/onboarding/OnboardingGate'
import { OnboardingScreen } from '@/features/onboarding/OnboardingScreen'
import { SettingsScreen } from '@/features/settings/SettingsScreen'
import { SocialScreen } from '@/features/social/SocialScreen'
import { TasksScreen } from '@/features/tasks/TasksScreen'
import { TodayScreen } from '@/features/today/TodayScreen'
import { AppLayout } from './layout/AppLayout'
import { NotFoundScreen } from './NotFoundScreen'
import { ROUTES } from './routes'

/** Feature ekranları burada kayıtlıdır; yeni ekran eklemek için yalnızca bu tabloya satır ekle. */
export const routes: RouteObject[] = [
  { path: ROUTES.onboarding, Component: OnboardingScreen },
  {
    // Onboarding tamamlanmadıysa /hos-geldin'e yönlendirir.
    Component: OnboardingGate,
    children: [
      {
        Component: AppLayout,
        children: [
          { index: true, Component: TodayScreen },
          { path: ROUTES.focus, Component: FocusScreen },
          { path: ROUTES.analysis, Component: AnalysisScreen },
          { path: ROUTES.books, Component: BooksScreen },
          { path: ROUTES.tasks, Component: TasksScreen },
          { path: ROUTES.social, Component: SocialScreen },
          { path: ROUTES.settings, Component: SettingsScreen },
          { path: '*', Component: NotFoundScreen },
        ],
      },
    ],
  },
]

export function createAppRouter() {
  return createBrowserRouter(routes)
}
