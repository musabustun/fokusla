import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ServicesProvider, type AppServices } from '@/data'
import { toISODate, type Book, type Subject, type TestResult, type Topic } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { TestResultSheet, type TestResultSheetProps } from './TestResultSheet'

type Overrides = Partial<Omit<TestResultSheetProps, 'open' | 'onClose' | 'subjects'>>

interface Fixture {
  math: Subject
  physics: Subject
  derivative: Topic
  integral: Topic
  book: Book
  archivedBook: Book
}

async function seed(services: AppServices): Promise<Fixture> {
  const { subjects, topics, books } = services.repositories
  const math = await subjects.create({
    name: 'Matematik',
    exam: 'AYT',
    fields: ['SAY'],
    catalogKey: 'ayt-matematik',
    order: 1,
  })
  const physics = await subjects.create({
    name: 'Fizik',
    exam: 'AYT',
    fields: ['SAY'],
    catalogKey: 'ayt-fizik',
    order: 2,
  })
  const integral = await topics.create({
    subjectId: math.id,
    name: 'İntegral',
    catalogKey: null,
    order: 2,
  })
  const derivative = await topics.create({
    subjectId: math.id,
    name: 'Türev',
    catalogKey: null,
    order: 1,
  })
  await topics.create({ subjectId: physics.id, name: 'Optik', catalogKey: null, order: 1 })
  const bookBase = {
    publisher: null,
    kind: 'questionBank',
    subjectId: math.id,
    exam: 'AYT',
    unit: 'test',
    totalUnits: null,
    barcode: null,
    libraryKey: null,
  } as const
  const book = await books.create({ ...bookBase, title: 'Limit Soru Bankası', archivedAt: null })
  const archivedBook = await books.create({
    ...bookBase,
    title: 'Eski Kitap',
    archivedAt: '2026-01-01T00:00:00.000Z',
  })
  return { math, physics, derivative, integral, book, archivedBook }
}

function Harness({
  subjects,
  onCloseSpy,
  ...props
}: Overrides & { subjects: readonly Subject[]; onCloseSpy: () => void }) {
  const [isOpen, setOpen] = useState(true)
  return (
    <TestResultSheet
      open={isOpen}
      onClose={() => {
        onCloseSpy()
        setOpen(false)
      }}
      subjects={subjects}
      {...props}
    />
  )
}

describe('TestResultSheet', () => {
  let ctx: TestServices
  let services: AppServices
  let fx: Fixture
  const onClose = vi.fn()

  beforeEach(async () => {
    ctx = createTestServices()
    services = ctx.services
    fx = await seed(services)
    onClose.mockReset()
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  function renderSheet(props: Overrides = {}) {
    render(
      <ServicesProvider services={services}>
        <Harness subjects={[fx.math, fx.physics]} onCloseSpy={onClose} {...props} />
      </ServicesProvider>,
    )
    return userEvent.setup()
  }

  async function allResults(): Promise<TestResult[]> {
    return services.repositories.testResults.findAll()
  }

  it('yeni test kaydeder: boş otomatik hesaplanır, takenAt bugünün yerel günüdür', async () => {
    const onSaved = vi.fn()
    const user = renderSheet({ onSaved })

    expect(screen.getByRole('heading', { name: 'Test ekle' })).toBeInTheDocument()
    await user.selectOptions(screen.getByLabelText('Ders'), fx.math.id)
    const topicSelect = screen.getByLabelText('Konu')
    await screen.findByRole('option', { name: 'Türev' })
    expect(Array.from((topicSelect as HTMLSelectElement).options, (option) => option.text)).toEqual(
      ['Konu seçilmedi', 'Türev', 'İntegral'],
    )
    await user.selectOptions(topicSelect, fx.integral.id)
    await user.type(screen.getByLabelText('Kitaptaki yer'), '  Test 12  ')
    await user.type(screen.getByLabelText('Soru sayısı'), '20')
    await user.type(screen.getByLabelText('Doğru'), '12')
    await user.type(screen.getByLabelText('Yanlış'), '4')

    const blank = screen.getByLabelText('Boş')
    expect(blank).toHaveAttribute('readonly')
    expect(blank).toHaveValue(4)
    expect(screen.getByRole('status')).toHaveTextContent('Net: 11,00 · Başarı %60')

    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    await waitFor(() => expect(onClose).toHaveBeenCalled())
    const [saved] = await allResults()
    expect(saved).toMatchObject({
      subjectId: fx.math.id,
      topicId: fx.integral.id,
      bookId: null,
      sourceName: null,
      label: 'Test 12',
      correct: 12,
      wrong: 4,
      blank: 4,
      durationSeconds: null,
      note: null,
    })
    expect(toISODate(new Date(saved?.takenAt ?? ''))).toBe(toISODate())
    expect(onSaved).toHaveBeenCalledWith(saved)
  })

  it('geçmiş bir gün seçilince takenAt o günün yerel öğlenidir', async () => {
    const user = renderSheet({ defaultSubjectId: fx.math.id })
    await user.type(screen.getByLabelText('Doğru'), '5')
    fireEvent.change(screen.getByLabelText('Tarih'), { target: { value: '2026-01-15' } })
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    await waitFor(() => expect(onClose).toHaveBeenCalled())
    const [saved] = await allResults()
    const takenAt = new Date(saved?.takenAt ?? '')
    expect(toISODate(takenAt)).toBe('2026-01-15')
    expect(takenAt.getHours()).toBe(12)
  })

  it('D+Y+B soru sayısını aşınca hata gösterir ve kaydetmez', async () => {
    const user = renderSheet({ defaultSubjectId: fx.math.id })
    await user.click(screen.getByRole('checkbox', { name: 'Boşu otomatik hesapla' }))
    await user.type(screen.getByLabelText('Soru sayısı'), '10')
    await user.type(screen.getByLabelText('Doğru'), '8')
    await user.type(screen.getByLabelText('Yanlış'), '2')
    await user.type(screen.getByLabelText('Boş'), '3')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    const questions = screen.getByLabelText('Soru sayısı')
    expect(questions).toHaveAttribute('aria-invalid', 'true')
    expect(questions).toHaveAccessibleDescription('Doğru + yanlış + boş, soru sayısını aşamaz.')
    expect(questions).toHaveFocus()
    expect(onClose).not.toHaveBeenCalled()
    expect(await allResults()).toHaveLength(0)
  })

  it('ders seçilmeden kaydetmez; hata düzeltilince kaybolur', async () => {
    const user = renderSheet()
    await user.type(screen.getByLabelText('Doğru'), '3')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    const subject = screen.getByLabelText('Ders')
    expect(subject).toHaveAccessibleDescription('Ders seçmelisin.')
    expect(subject).toHaveFocus()
    await user.selectOptions(subject, fx.physics.id)
    expect(subject).not.toHaveAttribute('aria-invalid')
    expect(await allResults()).toHaveLength(0)
  })

  it('ders değişince konu sıfırlanır', async () => {
    const user = renderSheet({ defaultSubjectId: fx.math.id, defaultTopicId: fx.derivative.id })
    const topic = screen.getByLabelText('Konu')
    await waitFor(() => expect(topic).toHaveValue(fx.derivative.id))
    await user.selectOptions(screen.getByLabelText('Ders'), fx.physics.id)
    expect(topic).toHaveValue('')
    expect(await screen.findByRole('option', { name: 'Optik' })).toBeInTheDocument()
  })

  it('serbest kaynak sourceName olarak kaydedilir, bookId null', async () => {
    const user = renderSheet({ defaultSubjectId: fx.math.id })
    expect(screen.queryByLabelText('Kaynak adı')).not.toBeInTheDocument()
    await user.selectOptions(screen.getByLabelText('Kaynak kitap'), 'Diğer (yaz)')
    await user.type(screen.getByLabelText('Kaynak adı'), 'Okul fasikülü')
    await user.type(screen.getByLabelText('Doğru'), '5')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    await waitFor(() => expect(onClose).toHaveBeenCalled())
    const [saved] = await allResults()
    expect(saved).toMatchObject({ bookId: null, sourceName: 'Okul fasikülü' })
  })

  it('kayıtlı kitap seçilince bookId kaydedilir; arşivli kitaplar listelenmez', async () => {
    const user = renderSheet({ defaultSubjectId: fx.math.id })
    await screen.findByRole('option', { name: 'Limit Soru Bankası' })
    expect(screen.queryByRole('option', { name: 'Eski Kitap' })).not.toBeInTheDocument()
    await user.selectOptions(screen.getByLabelText('Kaynak kitap'), fx.book.id)
    await user.type(screen.getByLabelText('Doğru'), '5')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    await waitFor(() => expect(onClose).toHaveBeenCalled())
    const [saved] = await allResults()
    expect(saved).toMatchObject({ bookId: fx.book.id, sourceName: null })
  })

  describe('düzenleme', () => {
    let existing: TestResult

    beforeEach(async () => {
      existing = await services.repositories.testResults.create({
        subjectId: fx.math.id,
        topicId: fx.derivative.id,
        bookId: fx.archivedBook.id,
        sourceName: null,
        label: 'Test 3',
        takenAt: new Date(2026, 10, 10, 9, 30).toISOString(),
        correct: 10,
        wrong: 4,
        blank: 6,
        durationSeconds: 900,
        note: 'not',
      })
    })

    it('formu doldurur ve günceller; tarih değişmediyse takenAt korunur', async () => {
      const onSaved = vi.fn()
      const user = renderSheet({ result: existing, onSaved })

      expect(screen.getByRole('heading', { name: 'Testi düzenle' })).toBeInTheDocument()
      expect(screen.getByLabelText('Ders')).toHaveValue(fx.math.id)
      await waitFor(() => expect(screen.getByLabelText('Konu')).toHaveValue(fx.derivative.id))
      await waitFor(() =>
        expect(screen.getByLabelText('Kaynak kitap')).toHaveValue(fx.archivedBook.id),
      )
      expect(screen.getByLabelText('Kitaptaki yer')).toHaveValue('Test 3')
      expect(screen.getByLabelText('Soru sayısı')).toHaveValue(20)
      expect(screen.getByLabelText('Boş')).toHaveValue(6)
      expect(screen.getByLabelText('Boş')).not.toHaveAttribute('readonly')
      expect(screen.getByRole('checkbox', { name: 'Boşu otomatik hesapla' })).not.toBeChecked()
      expect(screen.getByLabelText('Tarih')).toHaveValue('2026-11-10')

      const correct = screen.getByLabelText('Doğru')
      await user.clear(correct)
      await user.type(correct, '12')
      await user.clear(screen.getByLabelText('Boş'))
      await user.type(screen.getByLabelText('Boş'), '4')
      await user.click(screen.getByRole('button', { name: 'Kaydet' }))

      await waitFor(() => expect(onClose).toHaveBeenCalled())
      const updated = await services.repositories.testResults.findById(existing.id)
      expect(updated).toMatchObject({
        correct: 12,
        wrong: 4,
        blank: 4,
        takenAt: existing.takenAt,
        bookId: fx.archivedBook.id,
        durationSeconds: 900,
        note: 'not',
      })
      expect(onSaved).toHaveBeenCalledWith(updated)
    })

    it('otomatik boş kapatılınca hesaplanan değer elle düzenlenebilir kalır', async () => {
      const user = renderSheet({ defaultSubjectId: fx.math.id })
      await user.type(screen.getByLabelText('Soru sayısı'), '10')
      await user.type(screen.getByLabelText('Doğru'), '6')
      await user.click(screen.getByRole('checkbox', { name: 'Boşu otomatik hesapla' }))
      const blank = screen.getByLabelText('Boş')
      expect(blank).not.toHaveAttribute('readonly')
      expect(blank).toHaveValue(4)
      await user.click(screen.getByRole('checkbox', { name: 'Boşu otomatik hesapla' }))
      expect(blank).toHaveAttribute('readonly')
    })

    it('onay adımıyla siler', async () => {
      const onDeleted = vi.fn()
      const user = renderSheet({ result: existing, onDeleted })

      await user.click(screen.getByRole('button', { name: 'Sil' }))
      expect(screen.getByText('Silmek istediğine emin misin?')).toBeInTheDocument()
      await user.click(screen.getByRole('button', { name: 'Vazgeç' }))
      expect(screen.queryByText('Silmek istediğine emin misin?')).not.toBeInTheDocument()

      await user.click(screen.getByRole('button', { name: 'Sil' }))
      await user.click(screen.getByRole('button', { name: 'Evet, sil' }))

      await waitFor(() => expect(onDeleted).toHaveBeenCalledWith(existing.id))
      expect(onClose).toHaveBeenCalled()
      expect(await services.repositories.testResults.findById(existing.id)).toBeUndefined()
    })

    it('silme başarısız olursa hata gösterir', async () => {
      vi.spyOn(console, 'error').mockImplementation(() => undefined)
      vi.spyOn(services.repositories.testResults, 'delete').mockRejectedValue(new Error('db'))
      const user = renderSheet({ result: existing })
      await user.click(screen.getByRole('button', { name: 'Sil' }))
      await user.click(screen.getByRole('button', { name: 'Evet, sil' }))
      expect(await screen.findByRole('alert')).toHaveTextContent('Silinemedi')
      expect(onClose).not.toHaveBeenCalled()
    })
  })

  it('kaydetme başarısız olursa hata gösterir ve açık kalır', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => undefined)
    vi.spyOn(services.repositories.testResults, 'create').mockRejectedValue(new Error('db'))
    const user = renderSheet({ defaultSubjectId: fx.math.id })
    await user.type(screen.getByLabelText('Doğru'), '5')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Kaydedilemedi')
    expect(onClose).not.toHaveBeenCalled()
  })

  it('yeni kayıtta Sil düğmesi yoktur', () => {
    renderSheet()
    expect(screen.queryByRole('button', { name: 'Sil' })).not.toBeInTheDocument()
  })
})
