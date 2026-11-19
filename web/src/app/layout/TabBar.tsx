import { NavLink } from 'react-router'
import { cx } from '@/ui'
import { NAV_ITEMS } from '../routes'
import { NAV_ICONS } from './navIcons'

const TAB_ITEMS = NAV_ITEMS.filter((item) => item.inTabBar)

/** iPhone alt tab bar'ı (<768px). SwiftUI: `TabView`. */
export function TabBar() {
  return (
    <nav
      aria-label="Ana gezinme"
      className="fixed inset-x-0 bottom-0 z-20 border-t border-separator bg-surface/85 pb-[env(safe-area-inset-bottom)] backdrop-blur-xl backdrop-saturate-150 md:hidden"
    >
      <ul role="list" className="mx-auto flex max-w-lg">
        {TAB_ITEMS.map((item) => {
          const Icon = NAV_ICONS[item.icon]
          return (
            <li key={item.key} className="flex-1">
              <NavLink
                to={item.path}
                end={item.path === '/'}
                className={({ isActive }) =>
                  cx(
                    'flex min-h-12.5 flex-col items-center justify-center gap-0.5 pt-1.5 pb-1 text-caption font-medium',
                    isActive ? 'text-accent' : 'text-secondary-label',
                  )
                }
              >
                <Icon aria-hidden className="size-6" />
                {item.label}
              </NavLink>
            </li>
          )
        })}
      </ul>
    </nav>
  )
}
