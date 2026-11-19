import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { ROUTES } from '@/app/routes'
import { ServicesProvider, type AppServices } from '@/data'
import { toISODateTime } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { SocialScreen } from './SocialScreen'

function renderSocial(services: AppServices, initialPath: string = ROUTES.social) {
  const router = createMemoryRouter(
    [
      { path: ROUTES.social, Component: SocialScreen },
      { path: ROUTES.focus, element: <h1>Odak</h1> },
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

async function signInAndClaim(user: ReturnType<typeof userEvent.setup>, username: string) {
  await user.click(await screen.findByRole('button', { name: 'Apple ile Giriş' }))
  await user.type(await screen.findByLabelText('Kullanıcı adı'), username)
  await user.click(screen.getByRole('button', { name: 'Devam' }))
  await screen.findByRole('heading', { name: /Arkadaşlar \(\d+\)/ })
}

const friendsRegion = () => screen.getByRole('region', { name: /^Arkadaşlar \(/ })

describe('SocialScreen', () => {
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

  it('girişsiz kullanıcıya açıklama ve Apple ile Giriş gösterir', async () => {
    renderSocial(services)
    expect(await screen.findByRole('button', { name: 'Apple ile Giriş' })).toBeInTheDocument()
    expect(
      screen.getByText(/Yalnızca kullanıcı adın ve çalışma süren paylaşılır/),
    ).toBeInTheDocument()
  })

  it('giriş → kullanıcı adı → sosyal ana ekran', async () => {
    const user = userEvent.setup()
    renderSocial(services)

    await signInAndClaim(user, 'test_ogrenci')

    expect(screen.getByRole('button', { name: /Kullanıcı adı.*@test_ogrenci/ })).toBeVisible()
    expect(within(friendsRegion()).getByRole('button', { name: /@elif\.say/ })).toBeVisible()
    expect(screen.getByRole('button', { name: '@zeynep2027 isteğini kabul et' })).toBeVisible()
  })

  it('geçersiz ve alınmış kullanıcı adlarında Türkçe hata gösterir', async () => {
    const user = userEvent.setup()
    renderSocial(services)
    await user.click(await screen.findByRole('button', { name: 'Apple ile Giriş' }))
    const input = await screen.findByLabelText('Kullanıcı adı')

    await user.type(input, '1abc')
    await user.click(screen.getByRole('button', { name: 'Devam' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Bir harfle başlamalı.')

    await user.clear(input)
    await user.type(input, 'deniz_ea')
    await user.click(screen.getByRole('button', { name: 'Devam' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('alınmış')
  })

  it('kullanıcı adıyla arkadaş ekler', async () => {
    const user = userEvent.setup()
    renderSocial(services)
    await signInAndClaim(user, 'test_ogrenci')

    await user.click(screen.getByRole('button', { name: 'Arkadaş ekle' }))
    const sheet = await screen.findByRole('dialog', { name: 'Arkadaş ekle' })
    await user.type(within(sheet).getByLabelText('Kullanıcı adı'), 'deniz_ea')
    await user.click(within(sheet).getByRole('button', { name: 'İstek gönder' }))

    expect(await within(friendsRegion()).findByRole('button', { name: /@deniz_ea/ })).toBeVisible()
  })

  it('arkadaş sayfası canlı listeden okunur ve arkadaşlıktan çıkarır', async () => {
    const user = userEvent.setup()
    renderSocial(services)
    await signInAndClaim(user, 'test_ogrenci')

    await user.click(within(friendsRegion()).getByRole('button', { name: /@mert_ayt/ }))
    const sheet = await screen.findByRole('dialog', { name: '@mert_ayt' })
    expect(within(sheet).getByText(/Molada/)).toBeVisible()

    await user.click(within(sheet).getByRole('button', { name: 'Arkadaşlıktan çıkar' }))

    expect(screen.queryByRole('dialog', { name: '@mert_ayt' })).toBeNull()
    expect(within(friendsRegion()).queryByRole('button', { name: /@mert_ayt/ })).toBeNull()
  })

  it('bilinmeyen davet kodunda hata gösterir', async () => {
    const user = userEvent.setup()
    renderSocial(services)
    await signInAndClaim(user, 'test_ogrenci')

    await user.click(screen.getByRole('button', { name: 'Arkadaş ekle' }))
    const sheet = await screen.findByRole('dialog', { name: 'Arkadaş ekle' })
    await user.click(within(sheet).getByRole('radio', { name: 'Davet kodu' }))
    await user.type(within(sheet).getByLabelText('Davet kodu'), 'ZZZZ99')
    await user.click(within(sheet).getByRole('button', { name: 'İstek gönder' }))

    expect(await within(sheet).findByRole('alert')).toHaveTextContent('bulunamadı')
  })

  it('gelen isteği kabul eder', async () => {
    const user = userEvent.setup()
    renderSocial(services)
    await signInAndClaim(user, 'test_ogrenci')

    await user.click(screen.getByRole('button', { name: '@zeynep2027 isteğini kabul et' }))

    expect(
      await within(friendsRegion()).findByRole('button', { name: /@zeynep2027/ }),
    ).toBeVisible()
    expect(screen.queryByRole('button', { name: '@zeynep2027 isteğini kabul et' })).toBeNull()
  })

  it('arkadaşın odasına katılır, odadakileri gösterir ve çıkar', async () => {
    const user = userEvent.setup()
    renderSocial(services)
    await signInAndClaim(user, 'test_ogrenci')

    await user.click(await screen.findByRole('button', { name: 'Sabah kampı odasına katıl' }))

    const members = await screen.findByRole('list', { name: 'Odadakiler' })
    expect(within(members).getByText('@elif.say')).toBeVisible()
    expect(within(members).getByText('@test_ogrenci')).toBeVisible()
    expect(screen.getByRole('link', { name: "Odak'a git" })).toHaveAttribute('href', ROUTES.focus)

    await user.click(screen.getByRole('button', { name: 'Odadan çık' }))
    expect(await screen.findByRole('button', { name: 'Oda oluştur' })).toBeVisible()
  })

  it('oda oluşturur ve ev sahibi olarak kapatır', async () => {
    const user = userEvent.setup()
    renderSocial(services)
    await signInAndClaim(user, 'test_ogrenci')

    await user.click(screen.getByRole('button', { name: 'Oda oluştur' }))
    const sheet = await screen.findByRole('dialog', { name: 'Oda oluştur' })
    const nameInput = within(sheet).getByLabelText('Oda adı')
    await user.clear(nameInput)
    await user.type(nameInput, 'Gece çalışması')
    await user.click(within(sheet).getByRole('button', { name: 'Oluştur' }))

    expect(await screen.findByRole('heading', { name: 'Gece çalışması' })).toBeVisible()
    await user.click(screen.getByRole('button', { name: 'Odayı kapat' }))
    expect(await screen.findByRole('button', { name: 'Oda oluştur' })).toBeVisible()
  })

  it('kendi durumunu focus kayıtlarından okur', async () => {
    const now = new Date()
    const session = await services.repositories.focusSessions.create({
      subjectId: null,
      topicId: null,
      startedAt: toISODateTime(new Date(now.getTime() - 5 * 60_000)),
      endedAt: null,
      note: null,
    })
    await services.repositories.focusSegments.create({
      sessionId: session.id,
      kind: 'focus',
      startedAt: session.startedAt,
      endedAt: null,
    })
    const user = userEvent.setup()
    renderSocial(services)
    await signInAndClaim(user, 'test_ogrenci')

    const ownStatus = screen.getByRole('region', { name: 'Senin durumun' })
    expect(await within(ownStatus).findByText(/Odakta · 5 dk/)).toBeVisible()
    expect(await services.repositories.focusSessions.findAll()).toHaveLength(1)
  })

  it('görünürlük anahtarı kapatılınca gizli olduğunu açıklar', async () => {
    const user = userEvent.setup()
    renderSocial(services)
    await signInAndClaim(user, 'test_ogrenci')

    const toggle = screen.getByRole('switch', { name: 'Sosyalde görün' })
    expect(toggle).toHaveAttribute('aria-checked', 'true')
    await user.click(toggle)

    expect(await screen.findByText(/Şu an gizlisin/)).toBeVisible()
    expect(screen.getByRole('switch', { name: 'Sosyalde görün' })).toHaveAttribute(
      'aria-checked',
      'false',
    )
  })

  it('davet bağlantısı arkadaş ekleme sayfasını kodla açar', async () => {
    const user = userEvent.setup()
    await services.auth.signInWithApple()
    await services.social.refresh()
    await services.social.claimUsername('test_ogrenci')
    renderSocial(services, `${ROUTES.social}?davet=DENIZ3`)

    const sheet = await screen.findByRole('dialog', { name: 'Arkadaş ekle' })
    expect(within(sheet).getByLabelText('Davet kodu')).toHaveValue('DENIZ3')
    await user.click(within(sheet).getByRole('button', { name: 'İstek gönder' }))
    expect(await within(friendsRegion()).findByRole('button', { name: /@deniz_ea/ })).toBeVisible()
  })
})
