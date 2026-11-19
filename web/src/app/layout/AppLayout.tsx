import { Outlet, useLocation } from 'react-router'
import { Sidebar } from './Sidebar'
import { TabBar } from './TabBar'

/** Ekran girişi yalnızca üst düzey sekme değişince oynar (alt rotalar arasında değil). */
function sectionKey(pathname: string): string {
  return pathname.split('/')[1] ?? ''
}

/**
 * Uyarlanabilir uygulama kabuğu.
 * - <768px (iPhone): içerik + alt tab bar (inTabBar olan 5 sekme).
 * - ≥768px (iPad): sol kenar çubuğu (tüm sekmeler) + sağda içerik. İçerik büyük iPad/masaüstünde
 *   de ekranı kullansın diye geniş (max-w-6xl) tutulur; iki sütunlu düzenler `lg:`'de açılır.
 * Sekme değişince içerik tek bir kısa geçişle girer (opaklık + 6px; hareket azaltmada yok).
 */
export function AppLayout() {
  const { pathname } = useLocation()
  return (
    <div className="min-h-dvh bg-background text-label">
      <a
        href="#main"
        className="sr-only z-50 rounded-full bg-accent px-5 py-3 font-semibold text-accent-contrast focus:not-sr-only focus:fixed focus:top-3 focus:left-3"
      >
        İçeriğe geç
      </a>
      <Sidebar />
      <main
        id="main"
        tabIndex={-1}
        className="px-[max(1.25rem,env(safe-area-inset-left))] pt-[max(2rem,env(safe-area-inset-top))] pb-[calc(6rem+env(safe-area-inset-bottom))] focus:outline-none md:pr-10 md:pb-16 md:pl-70 lg:pl-76"
      >
        <div
          key={sectionKey(pathname)}
          className="mx-auto w-full max-w-6xl motion-safe:animate-screen-in"
        >
          <Outlet />
        </div>
      </main>
      <TabBar />
    </div>
  )
}
