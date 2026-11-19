import {
  BookOpen,
  ChartColumn,
  ListChecks,
  Settings,
  Sun,
  Timer,
  Users,
  type LucideIcon,
} from 'lucide-react'
import type { NavIcon } from '../routes'

/** routes.ts'teki ikon anahtarlarını lucide-react bileşenlerine çevirir (SwiftUI: SF Symbols). */
export const NAV_ICONS: Readonly<Record<NavIcon, LucideIcon>> = {
  sun: Sun,
  timer: Timer,
  chart: ChartColumn,
  book: BookOpen,
  check: ListChecks,
  users: Users,
  settings: Settings,
}
