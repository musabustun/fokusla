import { NavLink } from 'react-router'
import { cx } from '@/ui'
import { NAV_ITEMS, type NavItem } from '../routes'
import { NAV_ICONS } from './navIcons'

const MAIN_ITEMS = NAV_ITEMS.filter((item) => item.key !== 'settings')
const FOOTER_ITEMS = NAV_ITEMS.filter((item) => item.key === 'settings')

function SidebarLink({ item }: { item: NavItem }) {
  const Icon = NAV_ICONS[item.icon]
  return (
    <li>
      <NavLink
        to={item.path}
        end={item.path === '/'}
        className={({ isActive }) =>
          cx(
            'group flex min-h-11 items-center gap-3 rounded-md px-3 text-body transition-colors',
            isActive ? 'bg-accent font-semibold text-accent-contrast' : 'text-label active:bg-fill',
          )
        }
      >
        <Icon
          aria-hidden
          className="size-5.5 shrink-0 text-accent group-aria-[current=page]:text-accent-contrast"
        />
        {item.label}
      </NavLink>
    </li>
  )
}

/** iPadOS kenar çubuğu (≥768px). SwiftUI: `NavigationSplitView` sidebar. */
export function Sidebar() {
  return (
    <nav
      aria-label="Ana gezinme"
      className="fixed inset-y-0 left-0 z-20 hidden w-60 flex-col border-r border-separator bg-surface px-3 pt-[max(1.5rem,env(safe-area-inset-top))] pb-[max(1rem,env(safe-area-inset-bottom))] md:flex lg:w-64"
    >
      <p className="mb-4 px-3 text-title2">Fokus</p>
      <ul role="list" className="flex flex-col gap-0.5">
        {MAIN_ITEMS.map((item) => (
          <SidebarLink key={item.key} item={item} />
        ))}
      </ul>
      <ul role="list" className="mt-auto flex flex-col gap-0.5 border-t border-separator pt-3">
        {FOOTER_ITEMS.map((item) => (
          <SidebarLink key={item.key} item={item} />
        ))}
      </ul>
    </nav>
  )
}
