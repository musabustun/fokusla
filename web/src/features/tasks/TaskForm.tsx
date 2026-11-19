import { ChevronDown } from 'lucide-react'
import { useId, type ReactNode } from 'react'
import type { ISODate, TaskKind } from '@/domain'
import {
  FIELD_ERROR_CLASS,
  FIELD_HINT_CLASS,
  FIELD_LABEL_CLASS,
  SegmentedControl,
  cx,
  type SegmentedOption,
} from '@/ui'
import { INPUT_CLASS, TEXTAREA_CLASS } from './styles'
import type { SubjectGroup } from './subjectOptions'
import { NOTES_MAX_LENGTH, TITLE_MAX_LENGTH, UNIT_MAX_LENGTH, type TaskDraft } from './taskModel'
import type { TaskFormState } from './useTaskForm'
import { WeekdayPicker } from './WeekdayPicker'

const KIND_OPTIONS: readonly SegmentedOption<TaskKind>[] = [
  { value: 'routine', label: 'Rutin' },
  { value: 'assignment', label: 'Ödev' },
]

const FREQUENCY_OPTIONS: readonly SegmentedOption<TaskDraft['frequency']>[] = [
  { value: 'daily', label: 'Her gün' },
  { value: 'weekly', label: 'Belirli günler' },
]

interface FieldProps {
  label: string
  /** Kontrolün id'si; etiket buna bağlanır. Grup alanlarında verilmez. */
  htmlFor?: string
  error?: string
  errorId: string
  hint?: string
  children: ReactNode
}

function Field({ label, htmlFor, error, errorId, hint, children }: FieldProps) {
  return (
    <div className="flex flex-col gap-1.5">
      {htmlFor ? (
        <label htmlFor={htmlFor} className={FIELD_LABEL_CLASS}>
          {label}
        </label>
      ) : (
        <span className={FIELD_LABEL_CLASS}>{label}</span>
      )}
      {children}
      {hint && !error && <p className={FIELD_HINT_CLASS}>{hint}</p>}
      {error && (
        <p id={errorId} className={FIELD_ERROR_CLASS}>
          {error}
        </p>
      )}
    </div>
  )
}

export interface TaskFormFieldsProps {
  /** `<form id>`; dışarıdaki bir "Kaydet" düğmesi `form={id}` ile bağlanabilir. */
  id: string
  form: TaskFormState
  subjectGroups: readonly SubjectGroup[]
  today: ISODate
  /** Düzenlemede tür değiştirilemez. */
  kindLocked?: boolean
  /** Form içindeki ek eylemler (ör. Kaydet/Vazgeç). */
  children?: ReactNode
}

/** Görev oluşturma/düzenleme alanları. Durum `useTaskForm`'dan gelir. */
export function TaskFormFields({
  id,
  form,
  subjectGroups,
  today,
  kindLocked = false,
  children,
}: TaskFormFieldsProps) {
  const baseId = useId()
  const fieldId = (name: string) => `${baseId}-${name}`
  const errorId = (name: string) => `${baseId}-${name}-error`
  const { draft, errors, update } = form
  const isRoutine = draft.kind === 'routine'
  const invalidProps = (name: keyof typeof errors) =>
    errors[name]
      ? { 'aria-invalid': true as const, 'aria-describedby': errorId(name) }
      : { 'aria-invalid': undefined }

  return (
    <form id={id} noValidate onSubmit={form.handleSubmit} className="flex flex-col gap-5 pt-2">
      {!kindLocked && (
        <SegmentedControl
          aria-label="Tür"
          options={KIND_OPTIONS}
          value={draft.kind}
          onChange={(kind) => form.changeKind(kind, today)}
          fullWidth
        />
      )}

      <Field
        label="Başlık"
        htmlFor={fieldId('title')}
        error={errors.title}
        errorId={errorId('title')}
      >
        <input
          id={fieldId('title')}
          type="text"
          value={draft.title}
          maxLength={TITLE_MAX_LENGTH * 2}
          autoComplete="off"
          enterKeyHint="done"
          placeholder={isRoutine ? 'Ör. 50 paragraf sorusu' : 'Ör. Fizik ödev föyü 3'}
          onChange={(event) => update({ title: event.target.value })}
          className={INPUT_CLASS}
          {...invalidProps('title')}
        />
      </Field>

      {isRoutine ? (
        <Field label="Tekrar" error={errors.weekdays} errorId={errorId('weekdays')}>
          <SegmentedControl
            aria-label="Tekrar"
            options={FREQUENCY_OPTIONS}
            value={draft.frequency}
            onChange={(frequency) => update({ frequency })}
            fullWidth
          />
          {draft.frequency === 'weekly' && (
            <WeekdayPicker
              value={draft.weekdays}
              onChange={(weekdays) => update({ weekdays })}
              invalid={Boolean(errors.weekdays)}
              describedBy={errors.weekdays ? errorId('weekdays') : undefined}
            />
          )}
        </Field>
      ) : (
        <Field
          label="Son tarih"
          htmlFor={fieldId('dueDate')}
          error={errors.dueDate}
          errorId={errorId('dueDate')}
        >
          <input
            id={fieldId('dueDate')}
            type="date"
            value={draft.dueDate}
            onChange={(event) => update({ dueDate: event.target.value })}
            className={INPUT_CLASS}
            {...invalidProps('dueDate')}
          />
        </Field>
      )}

      <Field label="Ders" htmlFor={fieldId('subject')} errorId={errorId('subject')}>
        <div className="relative">
          <select
            id={fieldId('subject')}
            value={draft.subjectId}
            onChange={(event) => update({ subjectId: event.target.value })}
            className={cx(INPUT_CLASS, 'appearance-none pr-10')}
          >
            <option value="">Ders yok</option>
            {subjectGroups.map((group) => (
              <optgroup key={group.exam} label={group.exam}>
                {group.subjects.map((subject) => (
                  <option key={subject.id} value={subject.id}>
                    {subject.name}
                  </option>
                ))}
              </optgroup>
            ))}
          </select>
          <ChevronDown
            aria-hidden
            className="pointer-events-none absolute top-1/2 right-3 size-5 -translate-y-1/2 text-tertiary-label"
          />
        </div>
      </Field>

      <div className="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)] gap-3">
        <Field
          label="Hedef miktar"
          htmlFor={fieldId('target')}
          error={errors.targetQuantity}
          errorId={errorId('targetQuantity')}
        >
          <input
            id={fieldId('target')}
            type="number"
            inputMode="numeric"
            min={1}
            step={1}
            value={draft.targetQuantity}
            placeholder="İsteğe bağlı"
            onChange={(event) => update({ targetQuantity: event.target.value })}
            className={INPUT_CLASS}
            {...invalidProps('targetQuantity')}
          />
        </Field>
        <Field
          label="Birim"
          htmlFor={fieldId('unit')}
          error={errors.quantityUnit}
          errorId={errorId('quantityUnit')}
        >
          <input
            id={fieldId('unit')}
            type="text"
            value={draft.quantityUnit}
            maxLength={UNIT_MAX_LENGTH * 2}
            placeholder="soru"
            autoComplete="off"
            onChange={(event) => update({ quantityUnit: event.target.value })}
            className={INPUT_CLASS}
            {...invalidProps('quantityUnit')}
          />
        </Field>
      </div>

      <Field label="Not" htmlFor={fieldId('notes')} error={errors.notes} errorId={errorId('notes')}>
        <textarea
          id={fieldId('notes')}
          value={draft.notes}
          rows={3}
          maxLength={NOTES_MAX_LENGTH * 2}
          placeholder="İsteğe bağlı"
          onChange={(event) => update({ notes: event.target.value })}
          className={cx(TEXTAREA_CLASS, 'resize-y')}
          {...invalidProps('notes')}
        />
      </Field>

      {form.submitError && (
        <p
          role="alert"
          className="rounded-md bg-danger-subtle px-3 py-2 text-subheadline text-danger"
        >
          {form.submitError}
        </p>
      )}
      {children}
    </form>
  )
}
