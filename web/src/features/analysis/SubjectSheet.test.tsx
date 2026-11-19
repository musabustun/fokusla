import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ServicesProvider, type AppServices } from '@/data'
import type { Subject } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { SubjectSheet, SUBJECT_DELETE_MESSAGE, type SubjectSheetProps } from './SubjectSheet'
import { CUSTOM_ORDER_BASE } from './subjects'

type Overrides = Partial<Omit<SubjectSheetProps, 'open' | 'onClose'>>

describe('SubjectSheet', () => {
  let ctx: TestServices
  let services: AppServices
  const onClose = vi.fn()

  beforeEach(() => {
    ctx = createTestServices()
    services = ctx.services
    onClose.mockReset()
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  function Harness(props: Overrides) {
    const [isOpen, setOpen] = useState(true)
    return (
      <SubjectSheet
        open={isOpen}
        onClose={() => {
          onClose()
          setOpen(false)
        }}
        field="SAY"
        existingCount={0}
        {...props}
      />
    )
  }

  function renderSheet(props: Overrides = {}) {
    render(
      <ServicesProvider services={services}>
        <Harness {...props} />
      </ServicesProvider>,
    )
    return userEvent.setup()
  }

  function userSubject(overrides: Partial<Subject> = {}) {
    return services.repositories.subjects.create({
      name: 'Problemler',
      exam: 'TYT',
      fields: ['SAY'],
      catalogKey: null,
      order: CUSTOM_ORDER_BASE,
      ...overrides,
    })
  }

  it('kullanıcı dersi oluşturur', async () => {
    const onSaved = vi.fn()
    const user = renderSheet({ existingCount: 2, onSaved })

    expect(screen.getByRole('heading', { name: 'Ders ekle' })).toBeInTheDocument()
    expect(screen.getByRole('radio', { name: 'TYT' })).toBeChecked()
    await user.type(screen.getByLabelText('Ders adı'), '  Geometri  ')
    await user.click(screen.getByRole('radio', { name: 'AYT' }))
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    await waitFor(() => expect(onClose).toHaveBeenCalled())
    const [saved] = await services.repositories.subjects.findAll()
    expect(saved).toMatchObject({
      name: 'Geometri',
      exam: 'AYT',
      fields: ['SAY'],
      catalogKey: null,
      order: CUSTOM_ORDER_BASE + 2,
    })
    expect(onSaved).toHaveBeenCalledWith(saved)
  })

  it('boş adla kaydetmez ve hata gösterir', async () => {
    const user = renderSheet()
    await user.type(screen.getByLabelText('Ders adı'), '   ')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    const input = screen.getByLabelText('Ders adı')
    expect(input).toHaveAttribute('aria-invalid', 'true')
    expect(input).toHaveAccessibleDescription('Ders adı boş olamaz.')
    expect(input).toHaveFocus()
    expect(await services.repositories.subjects.findAll()).toHaveLength(0)
    expect(onClose).not.toHaveBeenCalled()
  })

  it('dersi yeniden adlandırır ve sınavını değiştirir', async () => {
    const subject = await userSubject()
    const user = renderSheet({ subject })

    expect(screen.getByRole('heading', { name: 'Dersi düzenle' })).toBeInTheDocument()
    const input = screen.getByLabelText('Ders adı')
    expect(input).toHaveValue('Problemler')
    await user.clear(input)
    await user.type(input, 'Sayı Problemleri')
    await user.click(screen.getByRole('radio', { name: 'AYT' }))
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    await waitFor(() => expect(onClose).toHaveBeenCalled())
    expect(await services.repositories.subjects.findById(subject.id)).toMatchObject({
      name: 'Sayı Problemleri',
      exam: 'AYT',
      order: CUSTOM_ORDER_BASE,
    })
  })

  it('silince konuları ve test sonuçlarını da siler', async () => {
    const { repositories } = services
    const subject = await userSubject()
    const other = await userSubject({ name: 'Başka' })
    const topic = await repositories.topics.create({
      subjectId: subject.id,
      name: 'Yaş problemleri',
      catalogKey: null,
      order: CUSTOM_ORDER_BASE,
    })
    const resultBase = {
      topicId: null,
      bookId: null,
      sourceName: null,
      label: null,
      takenAt: '2026-11-18T09:00:00.000Z',
      correct: 5,
      wrong: 1,
      blank: 0,
      durationSeconds: null,
      note: null,
    }
    await repositories.testResults.create({ ...resultBase, subjectId: subject.id })
    await repositories.testResults.create({
      ...resultBase,
      subjectId: subject.id,
      topicId: topic.id,
    })
    const kept = await repositories.testResults.create({ ...resultBase, subjectId: other.id })
    const onDeleted = vi.fn()
    const user = renderSheet({ subject, onDeleted })

    await user.click(screen.getByRole('button', { name: 'Sil' }))
    expect(screen.getByText(SUBJECT_DELETE_MESSAGE)).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Evet, sil' }))

    await waitFor(() => expect(onDeleted).toHaveBeenCalledWith(subject.id))
    expect(onClose).toHaveBeenCalled()
    expect(await repositories.subjects.findById(subject.id)).toBeUndefined()
    expect(await repositories.topics.findById(topic.id)).toBeUndefined()
    expect(await repositories.testResults.findAll()).toEqual([kept])
    const tombstone = await repositories.subjects.findById(subject.id, { includeDeleted: true })
    expect(tombstone?.deletedAt).not.toBeNull()
  })

  it('katalog derslerini düzenlemeye izin vermez', async () => {
    const subject = await userSubject({ catalogKey: 'tyt-matematik' })
    renderSheet({ subject })
    expect(screen.getByText('Müfredat dersleri düzenlenemez.')).toBeInTheDocument()
    expect(screen.queryByLabelText('Ders adı')).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Sil' })).not.toBeInTheDocument()
  })

  it('kaydetme başarısız olursa hata gösterir', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => undefined)
    vi.spyOn(services.repositories.subjects, 'create').mockRejectedValue(new Error('db'))
    const user = renderSheet()
    await user.type(screen.getByLabelText('Ders adı'), 'Geometri')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Kaydedilemedi')
    expect(onClose).not.toHaveBeenCalled()
  })
})
