import { useId, useState, type FormEvent } from 'react'
import { useServices } from '@/data'
import type { Topic, UUID } from '@/domain'
import { Button, Sheet } from '@/ui'
import { deleteTopicKeepingResults } from './cascade'
import { DeleteConfirm } from './DeleteConfirm'
import { MAX_TOPIC_NAME_LENGTH, validateEntityName } from './entityName'
import { FormField } from './FormField'
import { fieldA11y, INPUT_CLASS, SAVE_FAILED_MESSAGE } from './formStyles'
import { CUSTOM_ORDER_BASE, isCatalogEntity } from './subjects'

export interface TopicSheetProps {
  open: boolean
  onClose: () => void
  /** Konunun dersi. */
  subjectId: UUID
  /** Verilirse yeniden adlandırma modu. Yalnızca kullanıcı konuları (catalogKey null). */
  topic?: Topic
  /** Dersteki mevcut kullanıcı konusu sayısı; yeni konunun sırası CUSTOM_ORDER_BASE + existingCount. */
  existingCount: number
  onSaved?: (topic: Topic) => void
  onDeleted?: (id: UUID) => void
}

export const TOPIC_DELETE_MESSAGE =
  'Konu silinecek; test sonuçları derste "Konu seçilmedi" olarak kalır. Silmek istediğine emin misin?'

/** Kullanıcı tanımlı konu ekleme / yeniden adlandırma / silme sayfası. */
export function TopicSheet(props: TopicSheetProps) {
  const key = props.open ? `open-${props.topic?.id ?? 'new'}` : 'closed'
  return <TopicSheetContent key={key} {...props} />
}

function TopicSheetContent({
  open,
  onClose,
  subjectId,
  topic,
  existingCount,
  onSaved,
  onDeleted,
}: TopicSheetProps) {
  const { repositories } = useServices()
  const baseId = useId()
  const formId = `${baseId}-form`
  const nameId = `${baseId}-name`
  const [name, setName] = useState(topic?.name ?? '')
  const [isSubmitted, setSubmitted] = useState(false)
  const [isSaving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState<string | null>(null)

  if (topic && isCatalogEntity(topic)) {
    return (
      <Sheet open={open} onClose={onClose} title="Konu">
        <p className="text-body text-secondary-label">Müfredat konuları düzenlenemez.</p>
      </Sheet>
    )
  }

  const validation = validateEntityName(name, 'Konu adı', MAX_TOPIC_NAME_LENGTH)
  const nameError = isSubmitted && !validation.ok ? validation.error : undefined

  const save = (validName: string) =>
    topic
      ? repositories.topics.update(topic.id, { name: validName })
      : repositories.topics.create({
          subjectId,
          name: validName,
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
    if (!topic) return
    await deleteTopicKeepingResults(repositories, topic.id)
    onDeleted?.(topic.id)
    onClose()
  }

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={topic ? 'Konuyu düzenle' : 'Konu ekle'}
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
          {topic && (
            <DeleteConfirm
              message={TOPIC_DELETE_MESSAGE}
              onConfirm={handleDelete}
              disabled={isSaving}
            />
          )}
        </div>
      }
    >
      <form id={formId} noValidate onSubmit={(event) => void handleSubmit(event)}>
        <FormField id={nameId} label="Konu adı" error={nameError}>
          <input
            {...fieldA11y(nameId, nameError)}
            type="text"
            className={INPUT_CLASS}
            maxLength={MAX_TOPIC_NAME_LENGTH}
            placeholder="Ör. Karışım problemleri"
            value={name}
            onChange={(event) => setName(event.target.value)}
          />
        </FormField>
      </form>
    </Sheet>
  )
}
