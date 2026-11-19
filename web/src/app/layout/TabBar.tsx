import { NavLink } from 'react-router'
import { cx } from '@/ui'
import { NAV_ITEMS } from '../routes'
import { NAV_ICONS } from './navIcons'

const TAB_ITEMS = NAV_ITEMS.filter((item) => item.inTabBar)

/**
 * iPhone alt tab bar'ı (<768px): zemin rengi, üstte 1px çizgi. Seçili sekme ana metin rengi +
 * üstte kısa kehribar çizgi; diğerleri ikincil. SwiftUI: `TabView` + `.tint(Color("Accent"))`.
 */
export function TabBar() {
  return (
    <nav
      aria-label="Ana gezinme"
      className="fixed inset-x-0 bottom-0 z-20 border-t border-separator bg-background/90 pb-[env(safe-area-inset-bottom)] backdrop-blur-xl md:hidden"
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
                    'relative flex min-h-13 flex-col items-center justify-center gap-1 pt-2 pb-1.5 text-caption font-medium',
                    'transition-[color,transform] duration-200 ease-standard active:scale-95 motion-reduce:active:scale-100',
                    'before:absolute before:top-0 before:left-1/2 before:h-0.5 before:w-6 before:-translate-x-1/2 before:rounded-full before:bg-accent before:opacity-0 before:transition-opacity',
                    isActive ? 'text-label before:opacity-100' : 'text-secondary-label',
                  )
                }
              >
                <Icon aria-hidden className="size-5.5" strokeWidth={1.75} />
                {item.label}
              </NavLink>
            </li>
          )
        })}
      </ul>
    </nav>
  )
}
