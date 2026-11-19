import { BookOpen, Users } from 'lucide-react'
import { Link } from 'react-router'
import { ROUTES } from '@/app/routes'
import { useLocalToday, useNow } from '@/data'
import { ListRow, ListSection } from '@/ui'
import { BooksCard } from './BooksCard'
import { FocusCard } from './FocusCard'
import { FriendsCard } from './FriendsCard'
import { TasksCard } from './TasksCard'
import { TestsCard } from './TestsCard'
import { TodayHeader } from './TodayHeader'

/** Başlıktaki selamın güncel kalması için yeterli (dakikalık). */
const HEADER_REFRESH_MS = 60_000

/** Tab bar'da olmayan modüllere iPhone'da kısayol (iPad'de kenar çubuğu zaten gösterir). */
function MoreSection() {
  return (
    <ListSection header="Diğer" className="mt-10 md:hidden">
      <ListRow
        title="Kitaplar"
        icon={<BookOpen className="size-5.5" />}
        render={(props) => <Link to={ROUTES.books} {...props} />}
      />
      <ListRow
        title="Sosyal"
        icon={<Users className="size-5.5" />}
        render={(props) => <Link to={ROUTES.social} {...props} />}
      />
    </ListSection>
  )
}

/**
 * Bugün: günün bir bakışta özeti ve tek dokunuşla işe başlama.
 * iPhone: tek sütun, Odak en üstte. iPad yatay (lg): Odak tam genişlikte, altında iki sütunlu editoryal düzen.
 */
export function TodayScreen() {
  const today = useLocalToday()
  const now = useNow(HEADER_REFRESH_MS)
  return (
    <>
      <TodayHeader now={now} />
      <div className="flex flex-col gap-10">
        <FocusCard today={today} />
        <div className="grid items-start gap-10 lg:grid-cols-2 lg:gap-x-16">
          <TasksCard today={today} />
          <div className="flex flex-col gap-10">
            <TestsCard today={today} />
            <BooksCard today={today} />
            <FriendsCard today={today} />
          </div>
        </div>
      </div>
      <MoreSection />
    </>
  )
}
