import { ROUTES } from '@/app/routes'
import type { UUID } from '@/domain'

/** Kitap detayının yolu: `/kitaplar/<id>` (router'da `ROUTES.books` altında `:bookId` çocuğu). */
export function bookPath(bookId: UUID): string {
  return `${ROUTES.books}/${bookId}`
}
