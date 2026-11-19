import { X } from 'lucide-react'
import {
  useEffect,
  useId,
  useRef,
  type KeyboardEvent,
  type MouseEvent,
  type ReactNode,
  type SyntheticEvent,
} from 'react'

export interface SheetProps {
  open: boolean
  /** Esc, arka plana tıklama veya "Kapat" düğmesiyle çağrılır. Birden çok kez çağrılabilir. */
  onClose: () => void
  title: string
  /** Başlığın altındaki kısa açıklama (`aria-describedby`). */
  description?: string
  children: ReactNode
  /** Alt kısımdaki eylemler (ör. Kaydet butonu). */
  footer?: ReactNode
}

/** Modal olmayan ortamlarda (jsdom) `showModal` yoktur; `open` niteliğine düşer. */
function openDialog(dialog: HTMLDialogElement) {
  if (typeof dialog.showModal === 'function') dialog.showModal()
  else dialog.setAttribute('open', '')
  if (!dialog.contains(document.activeElement)) dialog.focus()
}

function closeDialog(dialog: HTMLDialogElement) {
  if (typeof dialog.close === 'function') dialog.close()
  else dialog.removeAttribute('open')
}

function useDialogSync(open: boolean) {
  const dialogRef = useRef<HTMLDialogElement>(null)
  useEffect(() => {
    const dialog = dialogRef.current
    if (!dialog || !open) return
    const returnFocusTo =
      document.activeElement instanceof HTMLElement ? document.activeElement : null
    if (!dialog.hasAttribute('open')) openDialog(dialog)
    return () => {
      if (dialog.hasAttribute('open')) closeDialog(dialog)
      returnFocusTo?.focus()
    }
  }, [open])
  return dialogRef
}

const DIALOG_CLASS = [
  'fixed inset-x-0 top-auto bottom-0 m-0 flex max-h-[92dvh] w-full max-w-none flex-col',
  'rounded-t-xl border-t border-separator bg-surface-elevated p-0 text-label backdrop:bg-scrim',
  'pb-[env(safe-area-inset-bottom)] not-open:hidden open:animate-sheet-in',
  'md:inset-0 md:m-auto md:h-fit md:max-h-[80dvh] md:max-w-lg md:rounded-xl md:border md:pb-0',
].join(' ')

/**
 * Modal sayfa: dar ekranda alttan açılan sheet, ≥768px'de ortalanmış form sheet.
 * Yerel `<dialog>` + `showModal()` kullanır (arka plan inert, odak içeri taşınır).
 */
export function Sheet({ open, onClose, title, description, children, footer }: SheetProps) {
  const dialogRef = useDialogSync(open)
  const titleId = useId()
  const descriptionId = useId()

  const handleCancel = (event: SyntheticEvent<HTMLDialogElement>) => {
    event.preventDefault()
    onClose()
  }
  const handleKeyDown = (event: KeyboardEvent<HTMLDialogElement>) => {
    if (event.key !== 'Escape') return
    event.preventDefault()
    onClose()
  }
  const handleBackdropClick = (event: MouseEvent<HTMLDialogElement>) => {
    if (event.target === event.currentTarget) onClose()
  }

  return (
    // Arka plan tıklaması yalnızca fare kolaylığıdır; klavye için Esc ve "Kapat" düğmesi vardır.
    <dialog
      ref={dialogRef}
      aria-modal="true"
      aria-labelledby={titleId}
      aria-describedby={description ? descriptionId : undefined}
      tabIndex={-1}
      className={DIALOG_CLASS}
      onCancel={handleCancel}
      onKeyDown={handleKeyDown}
      onClick={handleBackdropClick}
    >
      {open && (
        <>
          <div
            aria-hidden
            className="mx-auto mt-2 h-1 w-9 rounded-full bg-separator-strong md:hidden"
          />
          <header className="flex items-start gap-3 px-5 pt-3 pb-3">
            <div className="min-w-0 flex-1 pt-2">
              <h2 id={titleId} className="text-title3">
                {title}
              </h2>
              {description && (
                <p id={descriptionId} className="mt-0.5 text-subheadline text-secondary-label">
                  {description}
                </p>
              )}
            </div>
            <button
              type="button"
              aria-label="Kapat"
              onClick={onClose}
              className="-mr-2 flex size-11 shrink-0 items-center justify-center rounded-full text-secondary-label transition-[background-color,transform] duration-200 hover:bg-fill hover:text-label active:scale-97"
            >
              <X aria-hidden className="size-5" />
            </button>
          </header>
          <div className="min-h-0 flex-1 overflow-y-auto px-5 pb-5">{children}</div>
          {footer && <footer className="border-t border-separator px-5 py-3">{footer}</footer>}
        </>
      )}
    </dialog>
  )
}
