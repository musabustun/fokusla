import { Compass } from 'lucide-react'
import { Link } from 'react-router'
import { buttonStyles, EmptyState, ScreenHeader } from '@/ui'
import { ROUTES } from './routes'

export function NotFoundScreen() {
  return (
    <>
      <ScreenHeader title="Sayfa bulunamadı" />
      <EmptyState
        icon={<Compass />}
        title="Burada bir şey yok"
        message="Aradığın sayfa taşınmış ya da hiç var olmamış olabilir."
        action={
          <Link to={ROUTES.today} className={buttonStyles({ variant: 'tinted' })}>
            Bugün'e dön
          </Link>
        }
      />
    </>
  )
}
