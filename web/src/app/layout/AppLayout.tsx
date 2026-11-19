import { Outlet } from 'react-router'
import { Sidebar } from './Sidebar'
import { TabBar } from './TabBar'

/**
 * Uyarlanabilir uygulama kabuğu.
 * - <768px (iPhone): içerik + alt tab bar (inTabBar olan 5 sekme).
 * - ≥768px (iPad): sol kenar çubuğu (tüm sekmeler) + sağda okunaklı genişlikte içerik.
 */
export function AppLayout() {
  return (
    <div className="min-h-dvh bg-background text-label">
      <a
        href="#main"
        className="sr-only z-50 rounded-md bg-accent px-4 py-3 font-semibold text-accent-contrast focus:not-sr-only focus:fixed focus:top-3 focus:left-3"
      >
        İçeriğe geç
      </a>
      <Sidebar />
      <main
        id="main"
        tabIndex={-1}
        className="px-[max(1rem,env(safe-area-inset-left))] pt-[max(1.5rem,env(safe-area-inset-top))] pb-[calc(5rem+env(safe-area-inset-bottom))] focus:outline-none md:pr-8 md:pb-12 md:pl-68 lg:pl-80"
      >
        <div className="mx-auto w-full max-w-2xl">
          <Outlet />
        </div>
      </main>
      <TabBar />
    </div>
  )
}
