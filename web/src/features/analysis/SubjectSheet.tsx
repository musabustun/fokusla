import { useId, useState, type FormEvent } from 'react'
import { useServices } from '@/data'
import type { ExamType, Subject, UUID, YksField } from '@/domain'
import {
  Button,
  FIELD_ERROR_CLASS,
  FIELD_LABEL_CLASS,
  SegmentedControl,
  Sheet,
  type SegmentedOption,
} from '@/ui'
import { deleteSubjectCascade } from './cascade'
import { DeleteConfirm } from './DeleteConfirm'
import { MAX_SUBJECT_NAME_LENGTH, validateEntityName } from './entityName'
import { FormField } from './FormField'
import { fieldA11y, INPUT_CLASS, SAVE_FAILED_MESSAGE } from './formStyles'
import { CUSTOM_ORDER_BASE, isCatalogEntity } from './subjects'

export interface SubjectSheetProps {
  open: boolean
  onClose: () => void
  /** Kullanıcının YKS alanı; yeni ders `fields: [field]` ile oluşturulur. */
  field: YksField
  /** Verilirse yeniden adlandırma modu. Yalnızca kullanıcı dersleri (catalogKey null). */
  subject?: Subject
  /** Mevcut kullanıcı dersi sayısı; yeni dersin sırası CUSTOM_ORDER_BASE + existingCount. */
  existingCount: number
  onSaved?: (subject: Subject) => void
  onDeleted?: (id: UUID) => void
}

const EXAM_OPTIONS: readonly SegmentedOption<ExamType>[] = [
  { value: 'TYT', label: 'TYT' },
  { value: 'AYT', label: 'AYT' },
  { value: 'YDT', label: 'YDT' },
]

export const SUBJECT_DELETE_MESSAGE =
  'Bu ders, konuları ve test sonuçları silinecek. Silmek istediğine emin misin?'

/** Kullanıcı tanımlı ders ekleme / yeniden adlandırma / silme sayfası. */
export function SubjectSheet(props: SubjectSheetProps) {
  const key = props.open ? `open-${props.subject?.id ?? 'new'}` : 'closed'
  return <SubjectSheetContent key={key} {...props} />
}

function SubjectSheetContent({
  open,
  onClose,
  field,
  subject,
  existingCount,
  onSaved,
  onDeleted,
}: SubjectSheetProps) {
  const { repositories } = useServices()
  const baseId = useId()
  const formId = `${baseId}-form`
  const nameId = `${baseId}-name`
  const [name, setName] = useState(subject?.name ?? '')
  const [exam, setExam] = useState<ExamType>(subject?.exam ?? 'TYT')
  const [isSubmitted, setSubmitted] = useState(false)
  const [isSaving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState<string | null>(null)

  if (subject && isCatalogEntity(subject)) {
    return (
      <Sheet open={open} onClose={onClose} title="Ders">
        <p className="text-body text-secondary-label">Müfredat dersleri düzenlenemez.</p>
      </Sheet>
    )
  }

  const validation = validateEntityName(name, 'Ders adı', MAX_SUBJECT_NAME_LENGTH)
  const nameError = isSubmitted && !validation.ok ? validation.error : undefined

  const save = (validName: string) =>
    subject
      ? repositories.subjects.update(subject.id, { name: validName, exam })
      : repositories.subjects.create({
          name: validName,
          exam,
          fields: [field],
          catalogKey: null,
          order: CUSTOM_ORDER_BASE + existingCount,
        })

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setSubmitted(true)
    if (!validation.ok) {
      document.getElementById(nameId)?.focus()
      return
    }
    setSaving(true)
    setSaveError(null)
    try {
      const saved = await save(validation.name)
      onSaved?.(saved)
      onClose()
    } catch (cause) {
      console.error(cause)
      setSaveError(SAVE_FAILED_MESSAGE)
      setSaving(false)
    }
  }

  const handleDelete = async () => {
    if (!subject) return
    await deleteSubjectCascade(repositories, subject.id)
    onDeleted?.(subject.id)
    onClose()
  }

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={subject ? 'Dersi düzenle' : 'Ders ekle'}
      footer={
        <div className="flex flex-col gap-3">
          {saveError && (
            <p role="alert" className={FIELD_ERROR_CLASS}>
              {saveError}
            </p>
          )}
          <Button type="submit" form={formId} variant="filled" fullWidth loading={isSaving}>
            Kaydet
          </Button>
          {subject && (
            <DeleteConfirm
              message={SUBJECT_DELETE_MESSAGE}
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
        <FormField id={nameId} label="Ders adı" error={nameError}>
          <input
            {...fieldA11y(nameId, nameError)}
            type="text"
            className={INPUT_CLASS}
            maxLength={MAX_SUBJECT_NAME_LENGTH}
            placeholder="Ör. Problemler"
            value={name}
            onChange={(event) => setName(event.target.value)}
          />
        </FormField>
        <div className="flex flex-col gap-1.5">
          <span aria-hidden className={FIELD_LABEL_CLASS}>
            Sınav
          </span>
          <SegmentedControl
            aria-label="Sınav"
            options={EXAM_OPTIONS}
            value={exam}
            onChange={setExam}
            fullWidth
          />
        </div>
      </form>
    </Sheet>
  )
}
