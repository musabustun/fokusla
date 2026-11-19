import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ServicesProvider, type AppServices } from '@/data'
import type { Subject, Topic } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { CUSTOM_ORDER_BASE } from './subjects'
import { TOPIC_DELETE_MESSAGE, TopicSheet, type TopicSheetProps } from './TopicSheet'

type Overrides = Partial<Omit<TopicSheetProps, 'open' | 'onClose' | 'subjectId'>>

describe('TopicSheet', () => {
  let ctx: TestServices
  let services: AppServices
  let subject: Subject
  const onClose = vi.fn()

  beforeEach(async () => {
    ctx = createTestServices()
    services = ctx.services
    subject = await services.repositories.subjects.create({
      name: 'Matematik',
      exam: 'TYT',
      fields: ['SAY', 'EA', 'SOZ', 'DIL'],
      catalogKey: 'tyt-matematik',
      order: 1,
    })
    onClose.mockReset()
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  function Harness(props: Overrides) {
    const [isOpen, setOpen] = useState(true)
    return (
      <TopicSheet
        open={isOpen}
        onClose={() => {
          onClose()
          setOpen(false)
        }}
        subjectId={subject.id}
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

  function userTopic(overrides: Partial<Topic> = {}) {
    return services.repositories.topics.create({
      subjectId: subject.id,
      name: 'Yaş problemleri',
      catalogKey: null,
      order: CUSTOM_ORDER_BASE,
      ...overrides,
    })
  }

  it('kullanıcı konusu oluşturur', async () => {
    const onSaved = vi.fn()
    const user = renderSheet({ existingCount: 3, onSaved })

    expect(screen.getByRole('heading', { name: 'Konu ekle' })).toBeInTheDocument()
    await user.type(screen.getByLabelText('Konu adı'), ' Karışım problemleri ')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    await waitFor(() => expect(onClose).toHaveBeenCalled())
    const [saved] = await services.repositories.topics.findBySubject(subject.id)
    expect(saved).toMatchObject({
      subjectId: subject.id,
      name: 'Karışım problemleri',
      catalogKey: null,
      order: CUSTOM_ORDER_BASE + 3,
    })
    expect(onSaved).toHaveBeenCalledWith(saved)
  })

  it('boş adla kaydetmez', async () => {
    const user = renderSheet()
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(screen.getByLabelText('Konu adı')).toHaveAccessibleDescription('Konu adı boş olamaz.')
    expect(await services.repositories.topics.findAll()).toHaveLength(0)
  })

  it('konuyu yeniden adlandırır', async () => {
    const topic = await userTopic()
    const user = renderSheet({ topic })

    expect(screen.getByRole('heading', { name: 'Konuyu düzenle' })).toBeInTheDocument()
    const input = screen.getByLabelText('Konu adı')
    await user.clear(input)
    await user.type(input, 'Yaş soruları')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    await waitFor(() => expect(onClose).toHaveBeenCalled())
    expect(await services.repositories.topics.findById(topic.id)).toMatchObject({
      name: 'Yaş soruları',
      subjectId: subject.id,
    })
  })

  it('silince test sonuçları derste "Konu seçilmedi" olarak kalır', async () => {
    const { repositories } = services
    const topic = await userTopic()
    const result = await repositories.testResults.create({
      subjectId: subject.id,
      topicId: topic.id,
      bookId: null,
      sourceName: null,
      label: null,
      takenAt: '2026-11-18T09:00:00.000Z',
      correct: 5,
      wrong: 1,
      blank: 0,
      durationSeconds: null,
      note: null,
    })
    const onDeleted = vi.fn()
    const user = renderSheet({ topic, onDeleted })

    await user.click(screen.getByRole('button', { name: 'Sil' }))
    expect(screen.getByText(TOPIC_DELETE_MESSAGE)).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Evet, sil' }))

    await waitFor(() => expect(onDeleted).toHaveBeenCalledWith(topic.id))
    expect(await repositories.topics.findById(topic.id)).toBeUndefined()
    expect(await repositories.testResults.findById(result.id)).toMatchObject({
      subjectId: subject.id,
      topicId: null,
      deletedAt: null,
    })
  })

  it('katalog konularını düzenlemeye izin vermez', async () => {
    const topic = await userTopic({ catalogKey: 'tyt-matematik-sayilar' })
    renderSheet({ topic })
    expect(screen.getByText('Müfredat konuları düzenlenemez.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Sil' })).not.toBeInTheDocument()
  })

  it('kaydetme başarısız olursa hata gösterir', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => undefined)
    vi.spyOn(services.repositories.topics, 'create').mockRejectedValue(new Error('db'))
    const user = renderSheet()
    await user.type(screen.getByLabelText('Konu adı'), 'Kümeler')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Kaydedilemedi')
  })
})
