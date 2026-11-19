/**
 * Rota tablosu ve gezinme menüsü — TEK KAYNAK. Feature'lar link verirken buradaki
 * sabitleri kullanır (`ROUTES.focus`), string path yazmaz.
 * URL'ler Türkçedir; kod tanımlayıcıları İngilizcedir.
 */
export const ROUTES = {
  today: '/',
  focus: '/odak',
  analysis: '/analiz',
  books: '/kitaplar',
  tasks: '/gorevler',
  social: '/sosyal',
  settings: '/ayarlar',
  onboarding: '/hos-geldin',
} as const

export type RouteKey = keyof typeof ROUTES

/** lucide-react ikon adı ile eşleşen anahtar; layout ikon bileşenine çevirir. */
export type NavIcon = 'sun' | 'timer' | 'chart' | 'book' | 'check' | 'users' | 'settings'

export interface NavItem {
  key: Exclude<RouteKey, 'onboarding'>
  path: string
  /** Kullanıcıya görünen Türkçe etiket. */
  label: string
  icon: NavIcon
  /**
   * iPhone alt tab bar'ında görünür mü? (En fazla 5 sekme; geri kalanlar
   * iPad kenar çubuğunda ve iPhone'da "Bugün" ekranındaki kısayollarla erişilir.)
   */
  inTabBar: boolean
}

export const NAV_ITEMS: readonly NavItem[] = [
  { key: 'today', path: ROUTES.today, label: 'Bugün', icon: 'sun', inTabBar: true },
  { key: 'focus', path: ROUTES.focus, label: 'Odak', icon: 'timer', inTabBar: true },
  { key: 'analysis', path: ROUTES.analysis, label: 'Analiz', icon: 'chart', inTabBar: true },
  { key: 'books', path: ROUTES.books, label: 'Kitaplar', icon: 'book', inTabBar: false },
  { key: 'tasks', path: ROUTES.tasks, label: 'Görevler', icon: 'check', inTabBar: true },
  { key: 'social', path: ROUTES.social, label: 'Sosyal', icon: 'users', inTabBar: false },
  { key: 'settings', path: ROUTES.settings, label: 'Ayarlar', icon: 'settings', inTabBar: true },
]
