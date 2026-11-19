import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createMemoryRouter, Outlet, RouterProvider } from 'react-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ROUTES } from '@/app/routes'
import { AuthCancelledError, ServicesProvider, type AppServices } from '@/data'
import { createTestServices, type TestServices } from '@/test/services'
import { OnboardingGate } from './OnboardingGate'
import { OnboardingScreen } from './OnboardingScreen'

function renderApp(services: AppServices, initialPath: string = ROUTES.today) {
  const router = createMemoryRouter(
    [
      { path: ROUTES.onboarding, Component: OnboardingScreen },
      {
        Component: OnboardingGate,
        children: [
          {
            Component: Outlet,
            children: [{ index: true, element: <h1>Bugün</h1> }],
          },
        ],
      },
    ],
    { initialEntries: [initialPath] },
  )
  render(
    <ServicesProvider services={services}>
      <RouterProvider router={router} />
    </ServicesProvider>,
  )
  return router
}

async function goToAccountStep(fieldName: RegExp) {
  const user = userEvent.setup()
  await user.click(await screen.findByRole('button', { name: 'Başla' }))
  const next = screen.getByRole('button', { name: 'Devam' })
  expect(next).toBeDisabled()
  await user.click(screen.getByRole('radio', { name: fieldName }))
  expect(next).toBeEnabled()
  await user.click(next)
  return user
}

describe('Onboarding', () => {
  let ctx: TestServices
  let services: AppServices

  beforeEach(() => {
    localStorage.clear()
    ctx = createTestServices()
    services = ctx.services
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  it('profil yoksa kapı onboarding ekranına yönlendirir', async () => {
    const router = renderApp(services)
    expect(
      await screen.findByRole('heading', { level: 1, name: "Fokus'a hoş geldin" }),
    ).toBeInTheDocument()
    expect(router.state.location.pathname).toBe(ROUTES.onboarding)
  })

  it('"Şimdilik atla" ile profili kaydeder ve Bugün ekranına geçer', async () => {
    const router = renderApp(services)
    const user = await goToAccountStep(/Eşit Ağırlık/)

    await user.click(screen.getByRole('button', { name: 'Şimdilik atla' }))

    expect(await screen.findByRole('heading', { level: 1, name: 'Bugün' })).toBeInTheDocument()
    expect(router.state.location.pathname).toBe(ROUTES.today)
    const profile = await services.repositories.profiles.getCurrent()
    expect(profile).toMatchObject({ field: 'EA', appleUserId: null })
    expect(profile?.onboardingCompletedAt).not.toBeNull()
  })

  it('"Apple ile Giriş" (mock) ile Apple kimliğini profile yazar', async () => {
    renderApp(services)
    const user = await goToAccountStep(/Sayısal/)

    await user.click(screen.getByRole('button', { name: /Apple ile Giriş/ }))

    expect(await screen.findByRole('heading', { level: 1, name: 'Bugün' })).toBeInTheDocument()
    const profile = await services.repositories.profiles.getCurrent()
    expect(profile?.appleUserId).toMatch(/^mock-apple-/)
    expect(await services.auth.getSession()).not.toBeNull()
  })

  it('giriş iptal edilirse hata göstermeden hesap adımında kalır', async () => {
    vi.spyOn(services.auth, 'signInWithApple').mockRejectedValue(new AuthCancelledError())
    renderApp(services)
    const user = await goToAccountStep(/Sözel/)

    await user.click(screen.getByRole('button', { name: /Apple ile Giriş/ }))

    expect(await screen.findByRole('button', { name: /Apple ile Giriş/ })).toBeEnabled()
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()
    expect(await services.repositories.profiles.getCurrent()).toBeUndefined()
  })

  it('beklenmeyen hatada kullanıcıya mesaj gösterir', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => undefined)
    vi.spyOn(services.auth, 'signInWithApple').mockRejectedValue(new Error('ağ hatası'))
    renderApp(services)
    const user = await goToAccountStep(/Dil/)

    await user.click(screen.getByRole('button', { name: /Apple ile Giriş/ }))

    expect(await screen.findByRole('alert')).toHaveTextContent('tekrar dene')
  })

  it('geri düğmeleri önceki adıma döner ve seçimi korur', async () => {
    renderApp(services)
    const user = await goToAccountStep(/Sayısal/)
    await user.click(screen.getByRole('button', { name: 'Geri' }))
    expect(screen.getByRole('radio', { name: /Sayısal/ })).toBeChecked()
    await user.click(screen.getByRole('button', { name: 'Geri' }))
    expect(screen.getByRole('heading', { level: 1, name: "Fokus'a hoş geldin" })).toBeVisible()
  })

  it('onboarding tamamlandıysa ikinci açılışta gösterilmez', async () => {
    await services.repositories.profiles.create({
      displayName: null,
      field: 'SAY',
      appleUserId: null,
      targetExamYear: null,
      onboardingCompletedAt: '2026-11-19T08:00:00.000Z',
    })
    const router = renderApp(services, ROUTES.onboarding)
    expect(await screen.findByRole('heading', { level: 1, name: 'Bugün' })).toBeInTheDocument()
    expect(router.state.location.pathname).toBe(ROUTES.today)
  })
})
