import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ServicesProvider, type AppServices } from '@/data'
import { catalogEntityId, type Book, type ExamType, type Subject } from '@/domain'
import type { BookLibrary } from '@/library'
import { fixtureBook } from '@/library/fixtures'
import { createTestServices, type TestServices } from '@/test/services'
import { BookFormSheet, type BookFormSheetProps } from './BookFormSheet'
import { createBook } from './bookActions'

async function createSubject(
  services: AppServices,
  name: string,
  exam: ExamType,
  order: number,
): Promise<Subject> {
  return services.repositories.subjects.create({
    name,
    exam,
    fields: ['SAY'],
    catalogKey: null,
    order,
  })
}

function renderSheet(services: AppServices, props: Partial<BookFormSheetProps> = {}) {
  const onClose = vi.fn()
  const onSaved = vi.fn()
  render(
    <ServicesProvider services={services}>
      <MemoryRouter>
        <BookFormSheet open onClose={onClose} onSaved={onSaved} subjects={[]} {...props} />
      </MemoryRouter>
    </ServicesProvider>,
  )
  return { onClose, onSaved, user: userEvent.setup() }
}

describe('BookFormSheet', () => {
  let ctx: TestServices
  let services: AppServices
  let math: Subject
  let physics: Subject

  beforeEach(async () => {
    ctx = createTestServices()
    services = ctx.services
    math = await createSubject(services, 'Matematik', 'TYT', 0)
    physics = await createSubject(services, 'Fizik', 'AYT', 1)
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  it('ekleme modunda varsayılanları gösterir ve dersleri sınava göre gruplar', async () => {
    renderSheet(services, { subjects: [math, physics] })

    const dialog = screen.getByRole('dialog', { name: 'Kitap ekle' })
    expect(within(dialog).getByLabelText('Kitap adı')).toHaveValue('')
    await vi.waitFor(() => expect(within(dialog).getByLabelText('Kitap adı')).toHaveFocus())
    expect(within(dialog).getByLabelText('Ders')).toHaveValue('')
    expect(within(dialog).getByRole('option', { name: 'Ders seçilmedi' })).toBeInTheDocument()
    expect(within(dialog).getByRole('group', { name: 'TYT' })).toHaveTextContent('Matematik')
    expect(within(dialog).getByRole('group', { name: 'AYT' })).toHaveTextContent('Fizik')
    expect(within(dialog).queryByRole('group', { name: 'YDT' })).not.toBeInTheDocument()
    expect(within(dialog).getByLabelText('Tür')).toHaveValue('questionBank')
    expect(within(dialog).getByRole('radio', { name: 'Test' })).toBeChecked()
    expect(within(dialog).getByLabelText('Toplam')).toHaveAccessibleDescription(
      'Toplam test sayısı. Bilmiyorsan boş bırak.',
    )
  })

  it('ilerleme birimi değişince toplam ipucu da değişir', async () => {
    const { user } = renderSheet(services)
    const unit = screen.getByRole('radiogroup', { name: 'İlerleme birimi' })

    await user.click(within(unit).getByRole('radio', { name: 'Sayfa' }))

    expect(screen.getByLabelText('Toplam')).toHaveAccessibleDescription(
      'Toplam sayfa sayısı. Bilmiyorsan boş bırak.',
    )
  })

  it('kitabı oluşturur, onSaved ve onClose çağırır', async () => {
    const { user, onSaved, onClose } = renderSheet(services, { subjects: [math, physics] })

    await user.type(screen.getByLabelText('Kitap adı'), '  Fizik Soru Bankası  ')
    await user.type(screen.getByLabelText('Yayınevi'), 'Limit')
    await user.selectOptions(screen.getByLabelText('Ders'), 'Fizik')
    await user.selectOptions(screen.getByLabelText('Tür'), 'Konu anlatımı')
    await user.click(screen.getByRole('radio', { name: 'Bölüm' }))
    await user.type(screen.getByLabelText('Toplam'), '12')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    await vi.waitFor(() => expect(onClose).toHaveBeenCalledTimes(1))
    const books = await services.repositories.books.findAll()
    expect(books).toHaveLength(1)
    expect(books[0]).toMatchObject({
      title: 'Fizik Soru Bankası',
      publisher: 'Limit',
      subjectId: physics.id,
      exam: 'AYT',
      kind: 'lecture',
      unit: 'section',
      totalUnits: 12,
      archivedAt: null,
    })
    expect(onSaved).toHaveBeenCalledWith(books[0])
  })

  it('form gönderimiyle (Enter) kaydeder; toplam boşsa bilinmiyor (null)', async () => {
    const { user, onClose } = renderSheet(services)
    await user.type(screen.getByLabelText('Kitap adı'), 'Deneme Seti')

    // Kaydet formun dışında (Sheet altbilgisi) ama `form` niteliğiyle ona bağlı; tarayıcıda Enter
    // bu varsayılan butonu tetikler. user-event bunu taklit etmediği için form doğrudan gönderilir.
    const form = (screen.getByRole('button', { name: 'Kaydet' }) as HTMLButtonElement).form
    expect(form).not.toBeNull()
    fireEvent.submit(form as HTMLFormElement)

    await vi.waitFor(() => expect(onClose).toHaveBeenCalled())
    const [book] = await services.repositories.books.findAll()
    expect(book).toMatchObject({
      title: 'Deneme Seti',
      publisher: null,
      subjectId: null,
      totalUnits: null,
    })
  })

  it('boş adda hata gösterir ve kaydetmez', async () => {
    const { user, onClose } = renderSheet(services)

    await user.type(screen.getByLabelText('Kitap adı'), '   ')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Kitap adı boş olamaz.')
    expect(onClose).not.toHaveBeenCalled()
    expect(await services.repositories.books.findAll()).toHaveLength(0)
  })

  it.each(['0', '-3', '2.5'])('geçersiz toplamda (%s) hata gösterir', async (total) => {
    const { user, onClose } = renderSheet(services)

    await user.type(screen.getByLabelText('Kitap adı'), 'Kitap')
    await user.type(screen.getByLabelText('Toplam'), total)
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Toplam pozitif bir tam sayı olmalı.',
    )
    expect(onClose).not.toHaveBeenCalled()
  })

  it('beklenmeyen hatada genel bir mesaj gösterir', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => undefined)
    vi.spyOn(services.repositories.books, 'create').mockRejectedValue(new Error('disk dolu'))
    const { user, onClose } = renderSheet(services)

    await user.type(screen.getByLabelText('Kitap adı'), 'Kitap')
    await user.click(screen.getByRole('button', { name: 'Kaydet' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Lütfen tekrar dene')
    expect(screen.getByRole('button', { name: 'Kaydet' })).toBeEnabled()
    expect(onClose).not.toHaveBeenCalled()
  })

  describe('düzenleme modu', () => {
    let book: Book

    beforeEach(async () => {
      book = await createBook(services.repositories, {
        title: 'Matematik Soru Bankası',
        publisher: 'Karekök',
        kind: 'practiceExam',
        subjectId: math.id,
        unit: 'page',
        totalUnits: 240,
      })
    })

    it('alanları kitaptan doldurur ve günceller', async () => {
      const { user, onSaved, onClose } = renderSheet(services, {
        book,
        subjects: [math, physics],
      })

      expect(screen.getByRole('dialog', { name: 'Kitabı düzenle' })).toBeInTheDocument()
      expect(screen.getByLabelText('Kitap adı')).toHaveValue('Matematik Soru Bankası')
      expect(screen.getByLabelText('Yayınevi')).toHaveValue('Karekök')
      expect(screen.getByLabelText('Ders')).toHaveValue(math.id)
      expect(screen.getByLabelText('Tür')).toHaveValue('practiceExam')
      expect(screen.getByRole('radio', { name: 'Sayfa' })).toBeChecked()
      expect(screen.getByLabelText('Toplam')).toHaveValue(240)

      await user.clear(screen.getByLabelText('Kitap adı'))
      await user.type(screen.getByLabelText('Kitap adı'), 'Matematik Fasikül')
      await user.clear(screen.getByLabelText('Yayınevi'))
      await user.selectOptions(screen.getByLabelText('Ders'), 'Ders seçilmedi')
      await user.clear(screen.getByLabelText('Toplam'))
      await user.click(screen.getByRole('button', { name: 'Kaydet' }))

      await vi.waitFor(() => expect(onClose).toHaveBeenCalled())
      const updated = await services.repositories.books.findById(book.id)
      expect(updated).toMatchObject({
        title: 'Matematik Fasikül',
        publisher: null,
        subjectId: null,
        exam: null,
        totalUnits: null,
      })
      expect(onSaved).toHaveBeenCalledWith(expect.objectContaining({ id: book.id }))
      expect(await services.repositories.books.findAll()).toHaveLength(1)
    })

    it('yeniden açılınca kaydedilmemiş değişiklikleri atar', async () => {
      const user = userEvent.setup()
      const onClose = vi.fn()
      const view = (open: boolean) => (
        <ServicesProvider services={services}>
          <BookFormSheet open={open} onClose={onClose} book={book} subjects={[math]} />
        </ServicesProvider>
      )
      const { rerender } = render(view(true))
      await user.type(screen.getByLabelText('Kitap adı'), ' taslak')

      rerender(view(false))
      rerender(view(true))

      expect(screen.getByLabelText('Kitap adı')).toHaveValue('Matematik Soru Bankası')
    })
  })

  describe('barkod', () => {
    const library: BookLibrary = { version: 1, updatedAt: '2026-11-24', books: [fixtureBook()] }
    const FOUND_BARCODE = '9781234567897'
    const UNKNOWN_BARCODE = '9780306406157'

    async function search(user: ReturnType<typeof userEvent.setup>, barcode: string) {
      await user.type(screen.getByLabelText('Barkod'), barcode)
      await user.click(screen.getByRole('button', { name: 'Kütüphanede ara' }))
    }

    it('barkod boşken ara düğmesi kapalıdır', () => {
      renderSheet(services, { library })
      expect(screen.getByRole('button', { name: 'Kütüphanede ara' })).toBeDisabled()
      expect(screen.getByLabelText('Barkod')).toHaveAttribute('inputmode', 'numeric')
    })

    it('geçersiz barkodda alan hatası gösterir', async () => {
      const { user } = renderSheet(services, { library })

      await search(user, '9781234567890')

      expect(await screen.findByRole('alert')).toHaveTextContent(
        'Geçerli bir barkod değil. 13 haneli numarayı kontrol et.',
      )
      expect(screen.getByLabelText('Barkod')).toBeInvalid()
    })

    it('kaydederken geçersiz barkodu reddeder', async () => {
      const { user, onClose } = renderSheet(services, { library })
      await user.type(screen.getByLabelText('Kitap adı'), 'Kitap')
      await user.type(screen.getByLabelText('Barkod'), '123')
      await user.click(screen.getByRole('button', { name: 'Kaydet' }))

      expect(await screen.findByRole('alert')).toHaveTextContent('Geçerli bir barkod değil')
      expect(onClose).not.toHaveBeenCalled()
      expect(await services.repositories.books.findAll()).toHaveLength(0)
    })

    it('kullanıcıda aynı barkodlu kitap varsa kitaba bağlantı verir', async () => {
      const existing = await createBook(services.repositories, {
        title: 'Elimdeki Kitap',
        publisher: null,
        kind: 'other',
        subjectId: null,
        unit: 'page',
        totalUnits: null,
        barcode: FOUND_BARCODE,
      })
      const { user } = renderSheet(services, { library })

      await search(user, FOUND_BARCODE)

      expect(await screen.findByText(/Bu kitap zaten kitaplığında/)).toBeInTheDocument()
      expect(screen.getByRole('link', { name: 'Elimdeki Kitap' })).toHaveAttribute(
        'href',
        `/kitaplar/${existing.id}`,
      )
      expect(screen.getByLabelText('Kitap adı')).toHaveValue('')
    })

    it('katalogda bulunursa alanları doldurur, bölümleri listeler ve kaydeder', async () => {
      const subject = await services.repositories.subjects.create(
        { name: 'Matematik', exam: 'TYT', fields: ['SAY'], catalogKey: 'tyt-matematik', order: 0 },
        { id: await catalogEntityId('tyt-matematik') },
      )
      const topic = await services.repositories.topics.create(
        {
          subjectId: subject.id,
          name: 'Temel Kavramlar',
          catalogKey: 'tyt-matematik.temel-kavramlar',
          order: 0,
        },
        { id: await catalogEntityId('tyt-matematik.temel-kavramlar') },
      )
      const { user, onClose } = renderSheet(services, { library, subjects: [subject] })

      await search(user, '978-1-2345-6789-7')

      await vi.waitFor(() =>
        expect(screen.getByLabelText('Kitap adı')).toHaveValue(
          'Örnek Yayınları TYT Matematik Soru Bankası',
        ),
      )
      expect(screen.getByLabelText('Barkod')).toHaveValue(FOUND_BARCODE)
      expect(screen.getByLabelText('Yayınevi')).toHaveValue('Örnek Yayınları')
      expect(screen.getByLabelText('Ders')).toHaveValue(subject.id)
      expect(screen.getByLabelText('Toplam')).toHaveValue(40)
      const sections = screen.getByRole('region', { name: 'Bölümler (2)' })
      expect(within(sections).getByText('Temel Kavramlar')).toBeInTheDocument()
      expect(within(sections).getByText('Test 1–10')).toBeInTheDocument()
      expect(within(sections).getByText('Test 11–40')).toBeInTheDocument()

      await user.click(screen.getByRole('button', { name: 'Kaydet' }))
      await vi.waitFor(() => expect(onClose).toHaveBeenCalled())

      const [book] = await services.repositories.books.findAll()
      if (!book) throw new Error('kitap yok')
      expect(book).toMatchObject({
        barcode: FOUND_BARCODE,
        libraryKey: 'ornek-yayinlari-tyt-matematik-soru-bankasi',
        exam: 'TYT',
      })
      const saved = await services.repositories.bookSections.findByBook(book.id)
      expect(saved.map((s) => [s.title, s.order, s.startUnit, s.endUnit, s.topicId])).toEqual([
        ['Temel Kavramlar', 1, 1, 10, topic.id],
        ['Karma', 2, 11, 40, null],
      ])
    })

    it('barkod değişince bulunan kayıt bağı kopar', async () => {
      const { user, onClose } = renderSheet(services, { library })
      await search(user, FOUND_BARCODE)
      await screen.findByRole('region', { name: 'Bölümler (2)' })

      await user.type(screen.getByLabelText('Barkod'), '1')
      expect(screen.queryByRole('region', { name: /Bölümler/ })).not.toBeInTheDocument()
      await user.type(screen.getByLabelText('Barkod'), '{Backspace}{Backspace}')
      await user.clear(screen.getByLabelText('Barkod'))
      await user.click(screen.getByRole('button', { name: 'Kaydet' }))

      await vi.waitFor(() => expect(onClose).toHaveBeenCalled())
      const [book] = await services.repositories.books.findAll()
      if (!book) throw new Error('kitap yok')
      expect(book).toMatchObject({ barcode: null, libraryKey: null })
      expect(await services.repositories.bookSections.findByBook(book.id)).toHaveLength(0)
    })

    it('katalogda yoksa bilgi satırı gösterir ve elle girilen kitabı barkodla kaydeder', async () => {
      const { user, onClose } = renderSheet(services, { library })

      await search(user, UNKNOWN_BARCODE)

      expect(await screen.findByText('Bu kitap kütüphanede yok. Bilgileri elle gir.')).toBeVisible()
      await user.type(screen.getByLabelText('Kitap adı'), 'Elle Kitap')
      await user.click(screen.getByRole('button', { name: 'Kaydet' }))

      await vi.waitFor(() => expect(onClose).toHaveBeenCalled())
      const [book] = await services.repositories.books.findAll()
      expect(book).toMatchObject({
        title: 'Elle Kitap',
        barcode: UNKNOWN_BARCODE,
        libraryKey: null,
      })
    })

    it('düzenlemede barkodu gösterir ve günceller; kendi barkoduna "zaten var" demez', async () => {
      const book = await createBook(services.repositories, {
        title: 'Kitap',
        publisher: null,
        kind: 'other',
        subjectId: null,
        unit: 'page',
        totalUnits: null,
        barcode: '978-0-306-40615-7',
      })
      const { user, onClose } = renderSheet(services, { library, book })
      expect(screen.getByLabelText('Barkod')).toHaveValue(UNKNOWN_BARCODE)

      await user.click(screen.getByRole('button', { name: 'Kütüphanede ara' }))
      expect(await screen.findByText(/kütüphanede yok/)).toBeVisible()
      expect(screen.queryByText(/zaten kitaplığında/)).not.toBeInTheDocument()

      await user.clear(screen.getByLabelText('Barkod'))
      await user.type(screen.getByLabelText('Barkod'), FOUND_BARCODE)
      await user.click(screen.getByRole('button', { name: 'Kaydet' }))

      await vi.waitFor(() => expect(onClose).toHaveBeenCalled())
      expect(await services.repositories.books.findById(book.id)).toMatchObject({
        barcode: FOUND_BARCODE,
      })
    })
  })
})
