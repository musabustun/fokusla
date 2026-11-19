/**
 * Kitap ekle / düzenle formu (Sheet). Alan etiketleri e2e ve detay ekranı tarafından kullanılır;
 * değiştirirken onları da güncelle.
 */
import { useEffect, useId, useRef, useState, type FormEvent } from 'react'
import { useServices } from '@/data'
import type { Book, BookKind, BookUnit, ExamType, Subject, UUID } from '@/domain'
import { Button, SegmentedControl, Sheet } from '@/ui'
import { BookValidationError, createBook, updateBook, type BookInput } from './bookActions'
import {
  BOOK_KIND_LABELS,
  BOOK_KINDS,
  BOOK_UNIT_LABELS,
  BOOK_UNIT_NOUNS,
  BOOK_UNITS,
} from './bookLabels'
import { FormError, SelectField, TextField } from './FormField'

export interface BookFormSheetProps {
  open: boolean
  onClose: () => void
  /** Verilirse düzenleme modu ("Kitabı düzenle"); yoksa ekleme ("Kitap ekle"). */
  book?: Book
  /** Ders seçicisi için (useBooksData().subjects). */
  subjects: readonly Subject[]
  /** Kayıt başarılı olunca (oluşturulan/güncellenen kitapla) çağrılır; ardından onClose. */
  onSaved?: (book: Book) => void
}

const EXAMS: readonly ExamType[] = ['TYT', 'AYT', 'YDT']
const UNIT_OPTIONS = BOOK_UNITS.map((unit) => ({ value: unit, label: BOOK_UNIT_LABELS[unit] }))
const NO_SUBJECT = ''
const GENERIC_ERROR = 'Kitap kaydedilemedi. Lütfen tekrar dene.'

interface FormValues {
  title: string
  publisher: string
  subjectId: UUID | typeof NO_SUBJECT
  kind: BookKind
  unit: BookUnit
  /** Ham metin; boşsa "bilinmiyor". */
  total: string
}

function initialValues(book: Book | undefined): FormValues {
  return {
    title: book?.title ?? '',
    publisher: book?.publisher ?? '',
    subjectId: book?.subjectId ?? NO_SUBJECT,
    kind: book?.kind ?? 'questionBank',
    unit: book?.unit ?? 'test',
    total: book?.totalUnits == null ? '' : String(book.totalUnits),
  }
}

function toInput(values: FormValues): BookInput {
  const total = values.total.trim()
  return {
    title: values.title,
    publisher: values.publisher,
    kind: values.kind,
    subjectId: values.subjectId === NO_SUBJECT ? null : values.subjectId,
    unit: values.unit,
    // Geçersiz metin NaN olur; bookActions doğrulaması bunu reddeder.
    totalUnits: total === '' ? null : Number(total),
  }
}

function SubjectOptions({ subjects }: { subjects: readonly Subject[] }) {
  return EXAMS.map((exam) => {
    const inExam = subjects.filter((subject) => subject.exam === exam)
    if (inExam.length === 0) return null
    return (
      <optgroup key={exam} label={exam}>
        {inExam.map((subject) => (
          <option key={subject.id} value={subject.id}>
            {subject.name}
          </option>
        ))}
      </optgroup>
    )
  })
}

interface BookFormProps {
  formId: string
  book: Book | undefined
  subjects: readonly Subject[]
  onSavingChange: (saving: boolean) => void
  onDone: (book: Book) => void
}

/**
 * İlk alanı (Kitap adı) odaklar. Dialog, çocuk efektlerinden sonra açıldığı (ve kapalı dialog
 * içindeki öğe odak alamadığı) için `autoFocus` yerine bir sonraki tura ertelenir.
 */
function useInitialFocus() {
  const ref = useRef<HTMLFormElement>(null)
  useEffect(() => {
    const timer = window.setTimeout(() => ref.current?.querySelector('input')?.focus(), 0)
    return () => window.clearTimeout(timer)
  }, [])
  return ref
}

/** Sheet açıkken bağlanır; her açılışta değerler `book`'tan yeniden başlar. */
function BookForm({ formId, book, subjects, onSavingChange, onDone }: BookFormProps) {
  const { repositories } = useServices()
  const [values, setValues] = useState<FormValues>(() => initialValues(book))
  const [error, setError] = useState<string | null>(null)
  const formRef = useInitialFocus()

  const set = <K extends keyof FormValues>(key: K, value: FormValues[K]) =>
    setValues((current) => ({ ...current, [key]: value }))

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setError(null)
    onSavingChange(true)
    try {
      const input = toInput(values)
      const saved = book
        ? await updateBook(repositories, book.id, input)
        : await createBook(repositories, input)
      onDone(saved)
    } catch (caught) {
      if (caught instanceof BookValidationError) {
        setError(caught.message)
      } else {
        console.error('Kitap kaydedilemedi', caught)
        setError(GENERIC_ERROR)
      }
    } finally {
      onSavingChange(false)
    }
  }

  const unitNoun = BOOK_UNIT_NOUNS[values.unit]

  return (
    <form
      ref={formRef}
      id={formId}
      noValidate
      onSubmit={handleSubmit}
      className="flex flex-col gap-5 pt-2"
    >
      <TextField
        label="Kitap adı"
        required
        autoComplete="off"
        value={values.title}
        onChange={(event) => set('title', event.target.value)}
        placeholder="Ör. TYT Matematik Soru Bankası"
      />
      <TextField
        label="Yayınevi"
        autoComplete="off"
        value={values.publisher}
        onChange={(event) => set('publisher', event.target.value)}
        placeholder="İsteğe bağlı"
      />
      <SelectField
        label="Ders"
        value={values.subjectId}
        onChange={(event) => set('subjectId', event.target.value)}
      >
        <option value={NO_SUBJECT}>Ders seçilmedi</option>
        <SubjectOptions subjects={subjects} />
      </SelectField>
      <SelectField
        label="Tür"
        value={values.kind}
        onChange={(event) => set('kind', event.target.value as BookKind)}
      >
        {BOOK_KINDS.map((kind) => (
          <option key={kind} value={kind}>
            {BOOK_KIND_LABELS[kind]}
          </option>
        ))}
      </SelectField>
      <div className="flex flex-col gap-1.5">
        <span aria-hidden className="text-subheadline font-semibold text-label">
          İlerleme birimi
        </span>
        <SegmentedControl
          aria-label="İlerleme birimi"
          options={UNIT_OPTIONS}
          value={values.unit}
          onChange={(unit) => set('unit', unit)}
          fullWidth
        />
      </div>
      <TextField
        label="Toplam"
        type="number"
        inputMode="numeric"
        min={1}
        step={1}
        value={values.total}
        onChange={(event) => set('total', event.target.value)}
        hint={`Toplam ${unitNoun} sayısı. Bilmiyorsan boş bırak.`}
      />
      {error && <FormError>{error}</FormError>}
    </form>
  )
}

export function BookFormSheet({ open, onClose, book, subjects, onSaved }: BookFormSheetProps) {
  const formId = useId()
  const [isSaving, setSaving] = useState(false)

  const handleDone = (saved: Book) => {
    onSaved?.(saved)
    onClose()
  }

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={book ? 'Kitabı düzenle' : 'Kitap ekle'}
      footer={
        <Button type="submit" form={formId} fullWidth loading={isSaving}>
          Kaydet
        </Button>
      }
    >
      <BookForm
        formId={formId}
        book={book}
        subjects={subjects}
        onSavingChange={setSaving}
        onDone={handleDone}
      />
    </Sheet>
  )
}
