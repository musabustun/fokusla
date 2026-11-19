import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { describe, expect, it } from 'vitest'
import { NotFoundScreen } from '../NotFoundScreen'
import { NAV_ITEMS, ROUTES } from '../routes'
import { AppLayout } from './AppLayout'

function renderLayout(initialPath: string) {
  const router = createMemoryRouter(
    [
      {
        Component: AppLayout,
        children: [
          ...NAV_ITEMS.map((item) => ({
            path: item.path,
            element: <h1>{item.label} ekranı</h1>,
          })),
          { path: '*', Component: NotFoundScreen },
        ],
      },
    ],
    { initialEntries: [initialPath] },
  )
  render(<RouterProvider router={router} />)
}

function navigations() {
  const [sidebar, tabBar] = screen.getAllByRole('navigation', { name: 'Ana gezinme' })
  if (!sidebar || !tabBar) throw new Error('İki gezinme alanı bekleniyordu')
  return { sidebar, tabBar }
}

describe('AppLayout', () => {
  it('renders landmarks, skip link and the routed screen', () => {
    renderLayout(ROUTES.today)
    expect(screen.getByRole('link', { name: 'İçeriğe geç' })).toHaveAttribute('href', '#main')
    expect(screen.getByRole('main')).toHaveAttribute('id', 'main')
    expect(screen.getByRole('heading', { name: 'Bugün ekranı' })).toBeInTheDocument()
  })

  it('shows every nav item in the sidebar and only tab-bar items in the tab bar', () => {
    renderLayout(ROUTES.today)
    const { sidebar, tabBar } = navigations()
    expect(within(sidebar).getAllByRole('link')).toHaveLength(NAV_ITEMS.length)
    const tabLabels = within(tabBar)
      .getAllByRole('link')
      .map((link) => link.textContent)
    expect(tabLabels).toEqual(NAV_ITEMS.filter((item) => item.inTabBar).map((i) => i.label))
  })

  it('marks the active route with aria-current in both navigations', () => {
    renderLayout(ROUTES.analysis)
    const { sidebar, tabBar } = navigations()
    for (const nav of [sidebar, tabBar]) {
      expect(within(nav).getByRole('link', { name: 'Analiz' })).toHaveAttribute(
        'aria-current',
        'page',
      )
      expect(within(nav).getByRole('link', { name: 'Bugün' })).not.toHaveAttribute('aria-current')
    }
  })

  it('navigates when a tab is clicked', async () => {
    renderLayout(ROUTES.today)
    await userEvent.click(within(navigations().tabBar).getByRole('link', { name: 'Odak' }))
    expect(screen.getByRole('heading', { name: 'Odak ekranı' })).toBeInTheDocument()
    expect(within(navigations().sidebar).getByRole('link', { name: 'Odak' })).toHaveAttribute(
      'aria-current',
      'page',
    )
  })

  it('renders the not-found screen for unknown paths', () => {
    renderLayout('/yok-boyle-bir-yer')
    expect(screen.getByRole('heading', { level: 1, name: 'Sayfa bulunamadı' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: "Bugün'e dön" })).toHaveAttribute('href', '/')
  })
})
