import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { ROUTES } from '@/app/routes'
import { ServicesProvider, type AppServices } from '@/data'
import type { Subject, TestResult, Topic } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { AnalysisScreen } from './AnalysisScreen'
import { analysisHref } from './analysisLinks'

const localISO = (day: number, hour = 10) => new Date(2026, 10, day, hour).toISOString()

interface Seed {
  math: Subject
  physics: Subject
  custom: Subject
  problems: Topic
  powers: Topic
  functions: Topic
}

async function seed(services: AppServices): Promise<Seed> {
  const { profiles, subjects, topics } = services.repositories
  await profiles.create({
    displayName: null,
    field: 'SAY',
    appleUserId: null,
    targetExamYear: null,
    onboardingCompletedAt: '2026-11-19T08:00:00.000Z',
  })
  const math = await subjects.create({
    name: 'Matematik',
    exam: 'TYT',
    fields: ['SAY', 'EA', 'SOZ', 'DIL'],
    catalogKey: 'tyt-matematik',
    order: 1,
  })
  const physics = await subjects.create({
    name: 'Fizik',
    exam: 'AYT',
    fields: ['SAY'],
    catalogKey: 'ayt-fizik',
    order: 2,
  })
  // Başka alanın dersi görünmemeli.
  await subjects.create({
    name: 'Edebiyat',
    exam: 'AYT',
    fields: ['EA', 'SOZ'],
    catalogKey: 'ayt-edebiyat',
    order: 3,
  })
  const custom = await subjects.create({
    name: 'Kodlama',
    exam: 'TYT',
    fields: [],
    catalogKey: null,
    order: 1000,
  })
  const topic = (subjectId: string, name: string, order: number) =>
    topics.create({ subjectId, name, catalogKey: `k-${name}`, order })
  return {
    math,
    physics,
    custom,
    problems: await topic(math.id, 'Problemler', 0),
    powers: await topic(math.id, 'Üslü Sayılar', 1),
    functions: await topic(math.id, 'Fonksiyonlar', 2),
  }
}

function addResult(services: AppServices, patch: Partial<TestResult> & { subjectId: string }) {
  return services.repositories.testResults.create({
    topicId: null,
    bookId: null,
    label: null,
    sourceName: null,
    takenAt: localISO(19),
    correct: 10,
    wrong: 4,
    blank: 6,
    durationSeconds: null,
    note: null,
    ...patch,
  })
}

async function seedResults(services: AppServices, s: Seed) {
  const book = await services.repositories.books.create({
    title: 'Karekök',
    publisher: null,
    kind: 'questionBank',
    subjectId: s.math.id,
    exam: 'TYT',
    unit: 'test',
    totalUnits: null,
    barcode: null,
    libraryKey: null,
    archivedAt: null,
  })
  // Problemler: 2 test, 24 soru, zayıf.
  await addResult(services, {
    subjectId: s.math.id,
    topicId: s.problems.id,
    bookId: book.id,
    label: 'Test 3',
    takenAt: localISO(17),
    correct: 4,
    wrong: 6,
    blank: 2,
  })
  await addResult(services, {
    subjectId: s.math.id,
    topicId: s.problems.id,
    sourceName: 'Okul fasikülü',
    takenAt: localISO(19),
    correct: 6,
    wrong: 4,
    blank: 2,
  })
  // Üslü Sayılar: 20 soru, güçlü.
  await addResult(services, {
    subjectId: s.math.id,
    topicId: s.powers.id,
    takenAt: localISO(18),
    correct: 18,
    wrong: 2,
    blank: 0,
  })
  // Konusuz test.
  await addResult(services, { subjectId: s.math.id, label: 'Deneme 1', takenAt: localISO(16) })
}

function renderAt(services: AppServices, path: string = ROUTES.analysis) {
  const router = createMemoryRouter([{ path: ROUTES.analysis, Component: AnalysisScreen }], {
    initialEntries: [path],
  })
  render(
    <ServicesProvider services={services}>
      <RouterProvider router={router} />
    </ServicesProvider>,
  )
  return router
}

/** Ayrıntı bölmesi (iPad sol bölmesi `nav` "Dersler" dışında kalan kısım). */
const subjectNav = () => screen.getByRole('navigation', { name: 'Dersler' })

describe('AnalysisScreen', () => {
  let ctx: TestServices
  let services: AppServices

  beforeEach(() => {
    ctx = createTestServices()
    services = ctx.services
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  it('test yoksa boş durumu ve alanındaki dersleri gösterir', async () => {
    await seed(services)
    renderAt(services)

    expect(await screen.findByRole('heading', { name: 'Henüz test kaydın yok' })).toBeVisible()
    expect(screen.getByRole('heading', { level: 1, name: 'Analiz' })).toBeVisible()
    expect(screen.getAllByRole('link', { name: /Matematik/ })).toHaveLength(2)
    expect(screen.queryByRole('link', { name: /Edebiyat/ })).not.toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'İlk testini ekle' }))
    expect(await screen.findByRole('dialog', { name: 'Test ekle' })).toBeInTheDocument()
  })

  it('genel bakışta net özetini, trendi ve en zayıf konuyu gösterir', async () => {
    const s = await seed(services)
    await seedResults(services, s)
    renderAt(services)

    const summary = await screen.findByRole('region', { name: 'Genel durum' })
    // 4 test, 64 soru, net = 38 − 16/4 = 34
    expect(within(summary).getByText('34,00')).toBeVisible()
    expect(within(summary).getByText('64')).toBeVisible()
    expect(screen.getByRole('img', { name: /^Net trendi: 4 gün/ })).toBeInTheDocument()

    const weakest = screen.getByRole('region', { name: 'En zayıf konular' })
    const rows = within(weakest).getAllByRole('link')
    expect(rows[0]).toHaveTextContent('Problemler')
    expect(rows[0]).toHaveTextContent('Matematik · 24 soru')
    expect(rows[0]).toHaveTextContent('%42 · 7,50 net')
    expect(rows[0]).toHaveAttribute(
      'href',
      analysisHref({ subjectId: s.math.id, topicId: s.problems.id }),
    )
    expect(within(weakest).getByText('En az 20 soru çözülen konular gösterilir.')).toBeVisible()

    const tyt = within(subjectNav()).getByRole('region', { name: 'TYT' })
    expect(within(tyt).getByRole('link', { name: /Matematik/ })).toHaveTextContent(
      '34,00 net · %59',
    )
    expect(within(subjectNav()).getByRole('link', { name: /Fizik/ })).toHaveTextContent(
      'Henüz test yok',
    )
  })

  it('eşiği geçen konu yoksa "Yeterli veri yok" der', async () => {
    const s = await seed(services)
    await addResult(services, {
      subjectId: s.math.id,
      topicId: s.powers.id,
      correct: 5,
      wrong: 2,
      blank: 3,
    })
    renderAt(services)

    const weakest = await screen.findByRole('region', { name: 'En zayıf konular' })
    expect(within(weakest).getByText('Yeterli veri yok')).toBeVisible()
  })

  it('ders ayrıntısı hiç çalışılmamış konuları ve konusuz testleri listeler', async () => {
    const s = await seed(services)
    await seedResults(services, s)
    const router = renderAt(services, analysisHref({ subjectId: s.math.id }))

    expect(await screen.findByRole('heading', { level: 1, name: 'Matematik' })).toBeVisible()
    expect(screen.getByRole('link', { name: 'Geri: Analiz' })).toHaveAttribute('href', '/analiz')
    expect(within(subjectNav()).getByRole('link', { name: /Matematik/ })).toHaveAttribute(
      'aria-current',
      'page',
    )
    expect(screen.getByText(/Son çözülen: 19 Kas 2026/)).toBeVisible()

    const topics = screen.getByRole('region', { name: 'Konular' })
    const links = within(topics).getAllByRole('link')
    expect(links.map((l) => l.textContent)).toEqual([
      expect.stringContaining('Problemler'),
      expect.stringContaining('Üslü Sayılar'),
      expect.stringContaining('Fonksiyonlar'),
    ])
    expect(links[2]).toHaveTextContent('Henüz test yok')
    expect(links[1]).toHaveTextContent('%90 · 17,50 net')
    expect(links[1]).toHaveTextContent('20 soru · son 18 Kas')

    const untopiced = screen.getByRole('region', { name: 'Konu seçilmedi' })
    expect(within(untopiced).getByRole('button', { name: /Deneme 1/ })).toBeVisible()
    expect(screen.queryByRole('button', { name: 'Dersi düzenle' })).not.toBeInTheDocument()

    await userEvent.click(links[0] as HTMLElement)
    expect(await screen.findByRole('heading', { level: 1, name: 'Problemler' })).toBeVisible()
    expect(router.state.location.search).toBe(`?ders=${s.math.id}&konu=${s.problems.id}`)
  })

  it('kullanıcı dersinde düzenleme ve konu ekleme sayfalarını açar', async () => {
    const s = await seed(services)
    renderAt(services, analysisHref({ subjectId: s.custom.id }))

    expect(await screen.findByRole('heading', { level: 1, name: 'Kodlama' })).toBeVisible()
    expect(screen.getByRole('region', { name: 'Konular' })).toHaveTextContent('Henüz konu yok')
    await userEvent.click(screen.getByRole('button', { name: 'Dersi düzenle' }))
    expect(await screen.findByRole('dialog', { name: 'Dersi düzenle' })).toBeInTheDocument()
  })

  it('konu ekle sayfasını açar', async () => {
    const s = await seed(services)
    renderAt(services, analysisHref({ subjectId: s.math.id }))
    await userEvent.click(await screen.findByRole('button', { name: 'Konu ekle' }))
    expect(await screen.findByRole('dialog', { name: 'Konu ekle' })).toBeInTheDocument()
  })

  it('konu ayrıntısı testleri yeniden eskiye listeler ve düzenleme sayfasını açar', async () => {
    const s = await seed(services)
    await seedResults(services, s)
    const router = renderAt(
      services,
      analysisHref({ subjectId: s.math.id, topicId: s.problems.id }),
    )

    expect(await screen.findByRole('heading', { level: 1, name: 'Problemler' })).toBeVisible()
    const tests = screen.getByRole('region', { name: 'Testler' })
    const rows = within(tests).getAllByRole('button')
    expect(rows[0]).toHaveTextContent('Okul fasikülü')
    expect(rows[0]).toHaveTextContent('19 Kas 2026 · 6D 4Y 2B')
    expect(rows[0]).toHaveTextContent('5,00 net')
    expect(rows[1]).toHaveTextContent('Karekök · Test 3')
    expect(rows[1]).toHaveTextContent('2,50 net')

    await userEvent.click(rows[1] as HTMLElement)
    expect(await screen.findByRole('dialog', { name: 'Testi düzenle' })).toBeInTheDocument()

    const back = screen.getByRole('link', { name: 'Geri: Matematik' })
    await userEvent.click(back)
    expect(await screen.findByRole('heading', { level: 1, name: 'Matematik' })).toBeVisible()
    expect(router.state.location.search).toBe(`?ders=${s.math.id}`)
  })

  it('testi olmayan konuda boş durum gösterir', async () => {
    const s = await seed(services)
    renderAt(services, analysisHref({ subjectId: s.math.id, topicId: s.functions.id }))

    expect(await screen.findByRole('heading', { level: 1, name: 'Fonksiyonlar' })).toBeVisible()
    expect(screen.getByRole('heading', { name: 'Bu konuda henüz test yok' })).toBeVisible()
    await userEvent.click(screen.getByRole('button', { name: 'Test ekle' }))
    expect(await screen.findByRole('dialog', { name: 'Test ekle' })).toBeInTheDocument()
  })

  it('kullanıcı konusunda "Konuyu düzenle" sayfasını açar', async () => {
    const s = await seed(services)
    const own = await services.repositories.topics.create({
      subjectId: s.math.id,
      name: 'Kendi konum',
      catalogKey: null,
      order: 1000,
    })
    renderAt(services, analysisHref({ subjectId: s.math.id, topicId: own.id }))
    await userEvent.click(await screen.findByRole('button', { name: 'Konuyu düzenle' }))
    expect(await screen.findByRole('dialog', { name: 'Konuyu düzenle' })).toBeInTheDocument()
  })

  it('bilinmeyen ders kimliğinde "Ders bulunamadı" gösterir', async () => {
    await seed(services)
    renderAt(services, analysisHref({ subjectId: 'yok' }))
    expect(await screen.findByRole('heading', { name: 'Ders bulunamadı' })).toBeVisible()
    expect(screen.getByRole('link', { name: 'Analize dön' })).toHaveAttribute('href', '/analiz')
  })

  it('bilinmeyen konu kimliğinde ders ayrıntısına düşer', async () => {
    const s = await seed(services)
    renderAt(services, analysisHref({ subjectId: s.physics.id, topicId: s.problems.id }))
    expect(await screen.findByRole('heading', { level: 1, name: 'Fizik' })).toBeVisible()
  })

  it('"Ders ekle" ders ekleme sayfasını açar', async () => {
    await seed(services)
    renderAt(services)
    const [first] = await screen.findAllByRole('button', { name: 'Ders ekle' })
    await userEvent.click(first as HTMLElement)
    expect(await screen.findByRole('dialog', { name: 'Ders ekle' })).toBeInTheDocument()
  })
  it('yeni ders kaydedilince o dersin ayrıntısına gider', async () => {
    await seed(services)
    const router = renderAt(services)
    const user = userEvent.setup()
    const [add] = await screen.findAllByRole('button', { name: 'Ders ekle' })
    await user.click(add as HTMLElement)
    const dialog = await screen.findByRole('dialog', { name: 'Ders ekle' })
    await user.type(within(dialog).getByLabelText('Ders adı'), 'Geometri')
    await user.click(within(dialog).getByRole('button', { name: 'Kaydet' }))

    expect(await screen.findByRole('heading', { level: 1, name: 'Geometri' })).toBeVisible()
    expect(router.state.location.search).toMatch(/^\?ders=/)
  })

  it('seçili kullanıcı dersi silinince genel bakışa döner', async () => {
    const s = await seed(services)
    const router = renderAt(services, analysisHref({ subjectId: s.custom.id }))
    const user = userEvent.setup()
    await user.click(await screen.findByRole('button', { name: 'Dersi düzenle' }))
    await user.click(await screen.findByRole('button', { name: 'Sil' }))
    await user.click(await screen.findByRole('button', { name: 'Evet, sil' }))

    await waitFor(() => expect(router.state.location.search).toBe(''))
    expect(await screen.findByRole('heading', { name: 'Henüz test kaydın yok' })).toBeVisible()
    expect(screen.queryByRole('heading', { name: 'Ders bulunamadı' })).not.toBeInTheDocument()
  })

  it('seçili kullanıcı konusu silinince derse döner', async () => {
    const s = await seed(services)
    const own = await services.repositories.topics.create({
      subjectId: s.math.id,
      name: 'Kendi konum',
      catalogKey: null,
      order: 1000,
    })
    const router = renderAt(services, analysisHref({ subjectId: s.math.id, topicId: own.id }))
    const user = userEvent.setup()
    await user.click(await screen.findByRole('button', { name: 'Konuyu düzenle' }))
    await user.click(await screen.findByRole('button', { name: 'Sil' }))
    await user.click(await screen.findByRole('button', { name: 'Evet, sil' }))

    expect(await screen.findByRole('heading', { level: 1, name: 'Matematik' })).toBeVisible()
    expect(router.state.location.search).toBe(`?ders=${s.math.id}`)
  })
})
