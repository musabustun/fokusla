import { BookOpen, Users } from 'lucide-react'
import { Link } from 'react-router'
import { ROUTES } from '@/app/routes'
import { Card, ListRow, ListSection, ProgressRing, ScreenHeader } from '@/ui'

// Placeholder ekran — değerler sabittir; Bugün özeti ilgili modüller hazır olunca bağlanacak.

const DATE_FORMAT = new Intl.DateTimeFormat('tr-TR', {
  weekday: 'long',
  day: 'numeric',
  month: 'long',
})

function FocusSummaryCard() {
  return (
    <Card title="Odak" className="flex flex-col">
      <div className="flex items-center gap-5">
        <ProgressRing value={0} label="Günlük odak hedefi" size={96} strokeWidth={9}>
          <span className="text-headline">0%</span>
        </ProgressRing>
        <div>
          <p className="text-title2">Bugün 0 dk odak</p>
          <p className="mt-1 text-subheadline text-secondary-label">
            Günlük hedefin belirlendiğinde ilerlemen burada dolacak.
          </p>
        </div>
      </div>
    </Card>
  )
}

interface StatCardProps {
  title: string
  value: string
  caption: string
}

function StatCard({ title, value, caption }: StatCardProps) {
  return (
    <Card title={title}>
      <p className="text-title1">{value}</p>
      <p className="mt-1 text-subheadline text-secondary-label">{caption}</p>
    </Card>
  )
}

/** Tab bar'da olmayan modüllere iPhone'da kısayol (iPad'de kenar çubuğu zaten gösterir). */
function MoreSection() {
  return (
    <ListSection header="Diğer" className="mt-8 md:hidden">
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

export function TodayScreen() {
  return (
    <>
      <ScreenHeader title="Bugün" subtitle={DATE_FORMAT.format(new Date())} />
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="sm:col-span-2">
          <FocusSummaryCard />
        </div>
        <StatCard title="Görevler" value="—" caption="Bugün için görev yok" />
        <StatCard title="Son testler" value="—" caption="Henüz test kaydı yok" />
      </div>
      <MoreSection />
    </>
  )
}
