import { useId, useState, type FormEvent } from 'react'
import { useLiveData, useServices } from '@/data'
import {
  toISODate,
  type Book,
  type NewEntity,
  type Subject,
  type TestResult,
  type Topic,
  type UUID,
} from '@/domain'
import { accuracyOf, computeNet } from '@/domain/calc/tests'
import { Button, Sheet } from '@/ui'
import { DeleteConfirm } from './DeleteConfirm'
import { FormField } from './FormField'
import { fieldA11y, INPUT_CLASS, SAVE_FAILED_MESSAGE } from './formStyles'
import { formatNet, formatPercent } from './format'
import {
  emptyFormValues,
  formValuesFromResult,
  MAX_TEXT_LENGTH,
  OTHER_SOURCE,
  previewCounts,
  resolveBlank,
  takenAtFor,
  validateTestResultForm,
  type TestResultFormErrors,
  type TestResultFormInput,
  type TestResultFormValues,
} from './testResultForm'

export interface TestResultSheetProps {
  open: boolean
  onClose: () => void
  /** Kullanıcının alanına göre süzülmüş ve sıralanmış dersler. */
  subjects: readonly Subject[]
  /** Verilirse düzenleme modu. */
  result?: TestResult
  defaultSubjectId?: UUID
  defaultTopicId?: UUID | null
  onSaved?: (result: TestResult) => void
  onDeleted?: (id: UUID) => void
}

/** Test sonucu ekleme/düzenleme sayfası. Her açılışta form sıfırlanır. */
export function TestResultSheet(props: TestResultSheetProps) {
  const key = props.open ? `open-${props.result?.id ?? 'new'}` : 'closed'
  return <TestResultSheetContent key={key} {...props} />
}

type FieldKey = keyof TestResultFormValues

const FIELD_ORDER: readonly FieldKey[] = [
  'subjectId',
  'topicId',
  'bookId',
  'sourceName',
  'label',
  'questionCount',
  'correct',
  'wrong',
  'blank',
  'date',
]

const NUMBER_FIELDS = [
  { key: 'questionCount', label: 'Soru sayısı' },
  { key: 'correct', label: 'Doğru' },
  { key: 'wrong', label: 'Yanlış' },
  { key: 'blank', label: 'Boş' },
] as const satisfies readonly { key: FieldKey; label: string }[]

const NO_ERRORS: TestResultFormErrors = {}

function byOrderThenName<T extends { order: number; name: string }>(a: T, b: T): number {
  return a.order - b.order || a.name.localeCompare(b.name, 'tr-TR')
}

function useTopics(subjectId: string): readonly Topic[] {
  const { repositories } = useServices()
  const topics = useLiveData(
    () =>
      subjectId === ''
        ? Promise.resolve<Topic[]>([])
        : repositories.topics.findBySubject(subjectId),
    [repositories, subjectId],
  )
  return (topics ?? []).toSorted(byOrderThenName)
}

/** Rafa kaldırılmamış kitaplar; düzenlenen kaydın kitabı arşivlenmiş olsa da listede kalır. */
function useBookOptions(currentBookId: string): readonly Book[] | undefined {
  const { repositories } = useServices()
  const books = useLiveData(() => repositories.books.findAll(), [repositories])
  return books
    ?.filter((book) => book.archivedAt === null || book.id === currentBookId)
    .toSorted((a, b) => a.title.localeCompare(b.title, 'tr-TR'))
}

function toNewEntity(input: TestResultFormInput, now: Date): NewEntity<TestResult> {
  const { date, ...rest } = input
  return { ...rest, takenAt: takenAtFor(date, now), durationSeconds: null, note: null }
}

function previewText(values: TestResultFormValues): string | null {
  const counts = previewCounts(values)
  if (!counts) return null
  return `Net: ${formatNet(computeNet(counts))} · Başarı ${formatPercent(accuracyOf(counts))}`
}

function TestResultSheetContent({
  open,
  onClose,
  subjects,
  result,
  defaultSubjectId,
  defaultTopicId,
  onSaved,
  onDeleted,
}: TestResultSheetProps) {
  const { repositories } = useServices()
  const baseId = useId()
  const formId = `${baseId}-form`
  const fieldId = (key: FieldKey) => `${baseId}-${key}`
  const [today] = useState(() => toISODate())
  const [values, setValues] = useState<TestResultFormValues>(() =>
    result
      ? formValuesFromResult(result)
      : emptyFormValues(today, { subjectId: defaultSubjectId, topicId: defaultTopicId }),
  )
  const [isSubmitted, setSubmitted] = useState(false)
  const [isSaving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState<string | null>(null)
  const topics = useTopics(values.subjectId)
  const books = useBookOptions(values.bookId)

  const validation = validateTestResultForm(values, today)
  const errors = isSubmitted && !validation.ok ? validation.errors : NO_ERRORS
  const resolved = resolveBlank(values)
  const preview = previewText(values)
  const isMissingBook =
    values.bookId !== '' &&
    values.bookId !== OTHER_SOURCE &&
    books !== undefined &&
    !books.some((book) => book.id === values.bookId)

  const set = <K extends FieldKey>(key: K, value: TestResultFormValues[K]) =>
    setValues((previous) => ({ ...previous, [key]: value }))

  const toggleBlankAuto = (checked: boolean) =>
    setValues((previous) =>
      checked ? { ...previous, blankAuto: true } : { ...resolveBlank(previous), blankAuto: false },
    )

  const save = async (input: TestResultFormInput) => {
    const now = new Date()
    if (!result) return repositories.testResults.create(toNewEntity(input, now))
    const { date, ...rest } = input
    const takenAt =
      date === toISODate(new Date(result.takenAt)) ? result.takenAt : takenAtFor(date, now)
    return repositories.testResults.update(result.id, { ...rest, takenAt })
  }

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setSubmitted(true)
    if (!validation.ok) {
      const firstInvalid = FIELD_ORDER.find((key) => validation.errors[key])
      if (firstInvalid) document.getElementById(fieldId(firstInvalid))?.focus()
      return
    }
    setSaving(true)
    setSaveError(null)
    try {
      const saved = await save(validation.input)
      onSaved?.(saved)
      onClose()
    } catch (cause) {
      console.error(cause)
      setSaveError(SAVE_FAILED_MESSAGE)
      setSaving(false)
    }
  }

  const handleDelete = async () => {
    if (!result) return
    await repositories.testResults.delete(result.id)
    onDeleted?.(result.id)
    onClose()
  }

  const subjectMissing = values.subjectId !== '' && !subjects.some((s) => s.id === values.subjectId)

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={result ? 'Testi düzenle' : 'Test ekle'}
      footer={
        <div className="flex flex-col gap-3">
          {saveError && (
            <p role="alert" className="text-footnote text-danger">
              {saveError}
            </p>
          )}
          <Button type="submit" form={formId} variant="filled" fullWidth loading={isSaving}>
            Kaydet
          </Button>
          {result && (
            <DeleteConfirm
              message="Silmek istediğine emin misin?"
              onConfirm={handleDelete}
              disabled={isSaving}
            />
          )}
        </div>
      }
    >
      <form
        id={formId}
        noValidate
        onSubmit={(event) => void handleSubmit(event)}
        className="flex flex-col gap-4"
      >
        <FormField id={fieldId('subjectId')} label="Ders" error={errors.subjectId}>
          <select
            {...fieldA11y(fieldId('subjectId'), errors.subjectId)}
            className={INPUT_CLASS}
            value={values.subjectId}
            onChange={(event) =>
              setValues((previous) => ({
                ...previous,
                subjectId: event.target.value,
                topicId: '',
              }))
            }
          >
            <option value="" disabled>
              Ders seç
            </option>
            {subjectMissing && <option value={values.subjectId}>Kayıtlı ders</option>}
            {subjects.map((subject) => (
              <option key={subject.id} value={subject.id}>
                {subject.exam} · {subject.name}
              </option>
            ))}
          </select>
        </FormField>

        <FormField id={fieldId('topicId')} label="Konu" error={errors.topicId}>
          <select
            {...fieldA11y(fieldId('topicId'), errors.topicId)}
            className={INPUT_CLASS}
            value={values.topicId}
            disabled={values.subjectId === ''}
            onChange={(event) => set('topicId', event.target.value)}
          >
            <option value="">Konu seçilmedi</option>
            {topics.map((topic) => (
              <option key={topic.id} value={topic.id}>
                {topic.name}
              </option>
            ))}
          </select>
        </FormField>

        <FormField id={fieldId('bookId')} label="Kaynak kitap" error={errors.bookId}>
          <select
            {...fieldA11y(fieldId('bookId'), errors.bookId)}
            className={INPUT_CLASS}
            value={values.bookId}
            onChange={(event) => set('bookId', event.target.value)}
          >
            <option value="">Kitap yok</option>
            {isMissingBook && <option value={values.bookId}>Silinmiş kitap</option>}
            {books?.map((book) => (
              <option key={book.id} value={book.id}>
                {book.title}
              </option>
            ))}
            <option value={OTHER_SOURCE}>Diğer (yaz)</option>
          </select>
        </FormField>

        {values.bookId === OTHER_SOURCE && (
          <FormField id={fieldId('sourceName')} label="Kaynak adı" error={errors.sourceName}>
            <input
              {...fieldA11y(fieldId('sourceName'), errors.sourceName)}
              type="text"
              className={INPUT_CLASS}
              maxLength={MAX_TEXT_LENGTH}
              placeholder="Okul fasikülü"
              value={values.sourceName}
              onChange={(event) => set('sourceName', event.target.value)}
            />
          </FormField>
        )}

        <FormField id={fieldId('label')} label="Kitaptaki yer" error={errors.label}>
          <input
            {...fieldA11y(fieldId('label'), errors.label)}
            type="text"
            className={INPUT_CLASS}
            maxLength={MAX_TEXT_LENGTH}
            placeholder="Test 12 / s. 45"
            value={values.label}
            onChange={(event) => set('label', event.target.value)}
          />
        </FormField>

        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {NUMBER_FIELDS.map(({ key, label }) => {
            const isAutoBlank = key === 'blank' && values.blankAuto
            return (
              <FormField key={key} id={fieldId(key)} label={label} error={errors[key]}>
                <input
                  {...fieldA11y(fieldId(key), errors[key])}
                  type="number"
                  inputMode="numeric"
                  min={key === 'questionCount' ? 1 : 0}
                  step={1}
                  className={INPUT_CLASS}
                  readOnly={isAutoBlank}
                  value={isAutoBlank ? resolved.blank : values[key]}
                  onChange={(event) => set(key, event.target.value)}
                />
              </FormField>
            )
          })}
        </div>

        <label className="-my-1 flex min-h-11 items-center gap-3 text-body text-label">
          <input
            type="checkbox"
            className="size-5 accent-accent"
            checked={values.blankAuto}
            onChange={(event) => toggleBlankAuto(event.target.checked)}
          />
          Boşu otomatik hesapla
        </label>

        <FormField id={fieldId('date')} label="Tarih" error={errors.date}>
          <input
            {...fieldA11y(fieldId('date'), errors.date)}
            type="date"
            className={INPUT_CLASS}
            max={today}
            value={values.date}
            onChange={(event) => set('date', event.target.value)}
          />
        </FormField>

        <output
          htmlFor={NUMBER_FIELDS.map(({ key }) => fieldId(key)).join(' ')}
          className="rounded-md bg-accent-subtle px-3 py-2 text-headline text-label"
        >
          {preview ?? 'Net: —'}
        </output>
      </form>
    </Sheet>
  )
}
