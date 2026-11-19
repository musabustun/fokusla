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
            'group relative flex min-h-11 items-center gap-3 rounded-md px-3 text-callout',
            'transition-[background-color,color,transform] duration-200 ease-standard active:scale-98 motion-reduce:active:scale-100',
            'before:absolute before:inset-y-2.5 before:left-0 before:w-0.5 before:rounded-full before:bg-accent before:opacity-0 before:transition-opacity',
            isActive
              ? 'bg-fill font-semibold text-label before:opacity-100'
              : 'text-secondary-label hover:bg-fill hover:text-label',
          )
        }
      >
        <Icon aria-hidden className="size-5 shrink-0" strokeWidth={1.75} />
        {item.label}
      </NavLink>
    </li>
  )
}

/**
 * iPadOS kenar çubuğu (≥768px): zemin rengi, sağda 1px çizgi; seçili öğe solda kehribar çizgi.
 * SwiftUI: `NavigationSplitView` sidebar.
 */
export function Sidebar() {
  return (
    <nav
      aria-label="Ana gezinme"
      className="fixed inset-y-0 left-0 z-20 hidden w-60 flex-col border-r border-separator bg-background px-3 pt-[max(1.75rem,env(safe-area-inset-top))] pb-[max(1rem,env(safe-area-inset-bottom))] md:flex lg:w-64"
    >
      <p className="mb-8 flex items-center gap-2 px-3 font-display text-title1">
        <span aria-hidden className="size-2.5 rounded-full bg-accent" />
        Fokus
      </p>
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
