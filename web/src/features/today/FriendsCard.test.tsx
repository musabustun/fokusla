import { render, screen, within } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { ROUTES } from '@/app/routes'
import {
  ServicesProvider,
  type AppServices,
  type SocialFriend,
  type SocialService,
  type SocialSnapshot,
} from '@/data'
import { toISODate, toISODateTime, type PresenceState } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { FriendsCard } from './FriendsCard'

function renderCard(services: AppServices) {
  const router = createMemoryRouter(
    [
      { path: ROUTES.today, element: <FriendsCard today={toISODate(new Date())} /> },
      { path: ROUTES.social, element: <h1>Sosyal</h1> },
    ],
    { initialEntries: [ROUTES.today] },
  )
  const view = render(
    <ServicesProvider services={services}>
      <RouterProvider router={router} />
    </ServicesProvider>,
  )
  return { router, ...view }
}

const card = () => screen.getByRole('region', { name: 'Arkadaşlar' })

function friend(username: string, state: PresenceState): SocialFriend {
  const now = toISODateTime(new Date())
  return {
    userId: `user-${username}`,
    username,
    friendsSince: now,
    presence:
      state === 'offline'
        ? null
        : { state, sessionStartedAt: now, stateSince: now, todayFocusMs: 0, updatedAt: now },
  }
}

/** Yalnızca Bugün kartının kullandığı üç metodu gerçekleyen sabit sosyal servis. */
function fakeSocial(snapshot: SocialSnapshot): SocialService {
  const stub: Pick<SocialService, 'getSnapshot' | 'subscribe' | 'refresh'> = {
    getSnapshot: () => snapshot,
    subscribe: () => () => undefined,
    refresh: () => Promise.resolve(),
  }
  return stub as SocialService
}

function readySnapshot(friends: readonly SocialFriend[]): SocialSnapshot {
  return {
    status: 'ready',
    profile: { userId: 'me', username: 'ben', inviteCode: 'ABC234', isDiscoverable: true },
    friends,
    requests: [],
    room: null,
    friendRooms: [],
  }
}

describe('FriendsCard', () => {
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

  const withSocial = (snapshot: SocialSnapshot): AppServices => ({
    ...services,
    social: fakeSocial(snapshot),
  })

  it('yüklenirken hiçbir şey göstermez', () => {
    const { container } = renderCard(withSocial({ ...readySnapshot([]), status: 'loading' }))
    expect(container).toBeEmptyDOMElement()
  })

  it('girişsiz kullanıcıya Sosyal davetini gösterir', async () => {
    renderCard(services)

    const link = await within(await screen.findByRole('region', { name: 'Arkadaşlar' })).findByRole(
      'link',
      { name: "Sosyal'e göz at" },
    )
    expect(link).toHaveAttribute('href', ROUTES.social)
    expect(within(card()).getByText('Arkadaşlarınla aynı anda odaklan.')).toBeVisible()
    expect(within(card()).queryByRole('link', { name: 'Tümü: Sosyal ekranı' })).toBeNull()
  })

  it('kullanıcı adı yoksa seçmeye yönlendirir', async () => {
    await services.auth.signInWithApple()
    renderCard(services)

    const link = await screen.findByRole('link', { name: 'Kullanıcı adı seç' })
    expect(link).toHaveAttribute('href', ROUTES.social)
    expect(within(card()).getByText('Sosyal için bir kullanıcı adı seç.')).toBeVisible()
  })

  it('arkadaş yoksa arkadaş eklemeye yönlendirir', () => {
    renderCard(withSocial(readySnapshot([])))

    expect(within(card()).getByText('Henüz arkadaşın yok.')).toBeVisible()
    expect(within(card()).getByRole('link', { name: 'Arkadaş ekle' })).toHaveAttribute(
      'href',
      ROUTES.social,
    )
  })

  it('odakta arkadaş yoksa bunu söyler', () => {
    renderCard(withSocial(readySnapshot([friend('mert', 'onBreak'), friend('ece', 'offline')])))

    expect(within(card()).getByText('Şu an odakta arkadaşın yok.')).toBeVisible()
    expect(within(card()).queryByRole('list', { name: 'Odaktaki arkadaşlar' })).toBeNull()
    expect(within(card()).getByRole('link', { name: 'Tümü: Sosyal ekranı' })).toHaveAttribute(
      'href',
      ROUTES.social,
    )
  })

  it('odaktaki arkadaşları yalnızca kullanıcı adıyla, en fazla 5 tane gösterir', () => {
    const focusing = ['zeynep', 'ali', 'can', 'deniz', 'elif', 'fatih', 'gül'].map((name) =>
      friend(name, 'focusing'),
    )
    renderCard(withSocial(readySnapshot([...focusing, friend('mert', 'onBreak')])))

    expect(within(card()).getByText('Şu an 7 arkadaşın odakta')).toBeVisible()
    const list = within(card()).getByRole('list', { name: 'Odaktaki arkadaşlar' })
    const names = within(list)
      .getAllByRole('listitem')
      .map((item) => item.textContent)
    expect(names).toEqual(['@ali', '@can', '@deniz', '@elif', '@fatih'])
    expect(within(card()).getByText('ve 2 kişi daha')).toBeVisible()
    expect(within(card()).queryByText('@mert')).toBeNull()
  })
})
