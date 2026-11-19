import { render, screen, within } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { ROUTES } from '@/app/routes'
import { ServicesProvider, type AppServices } from '@/data'
import { toISODate, toISODateTime, type Subject, type TestResult, type Topic } from '@/domain'
import { createTestServices, type TestServices } from '@/test/services'
import { TestsCard } from './TestsCard'

const DAY_MS = 24 * 60 * 60 * 1000

function renderCard(services: AppServices) {
  const today = toISODate(new Date())
  const router = createMemoryRouter(
    [
      { path: ROUTES.today, element: <TestsCard today={today} /> },
      { path: ROUTES.analysis, element: <h1>Analiz</h1> },
    ],
    { initialEntries: [ROUTES.today] },
  )
  render(
    <ServicesProvider services={services}>
      <RouterProvider router={router} />
    </ServicesProvider>,
  )
  return router
}

const card = () => screen.getByRole('region', { name: 'Son testler' })

/** `<dt>` etiketine karşılık gelen `<dd>` metni. */
function statValue(label: string): string | null {
  const term = within(card()).getByText(label, { selector: 'dt' })
  return term.nextElementSibling?.textContent ?? null
}

describe('TestsCard', () => {
  let ctx: TestServices
  let services: AppServices
  let math: Subject
  let derivative: Topic
  let limits: Topic

  const addResult = (patch: Partial<TestResult> & Pick<TestResult, 'correct' | 'wrong'>) =>
    services.repositories.testResults.create({
      subjectId: math.id,
      topicId: null,
      bookId: null,
      label: null,
      sourceName: null,
      takenAt: toISODateTime(new Date()),
      blank: 0,
      durationSeconds: null,
      note: null,
      ...patch,
    })

  beforeEach(async () => {
    ctx = createTestServices()
    services = ctx.services
    math = await services.repositories.subjects.create({
      name: 'Matematik',
      exam: 'TYT',
      fields: ['SAY', 'EA'],
      catalogKey: null,
      order: 0,
    })
    derivative = await services.repositories.topics.create({
      subjectId: math.id,
      name: 'Türev',
      catalogKey: null,
      order: 0,
    })
    limits = await services.repositories.topics.create({
      subjectId: math.id,
      name: 'Limit',
      catalogKey: null,
      order: 1,
    })
  })

  afterEach(async () => {
    await ctx.dispose()
  })

  it('test yoksa boş durumu ve analiz bağlantısını gösterir', async () => {
    renderCard(services)

    const link = await within(card()).findByRole('link', { name: 'İlk testini ekle' })
    expect(within(card()).getByText('Henüz test yok.')).toBeVisible()
    expect(link).toHaveAttribute('href', ROUTES.analysis)
    expect(within(card()).queryByRole('link', { name: 'Analiz ekranı' })).toBeNull()
  })

  it('bugün, son 7 gün ve net özetini gösterir; zayıf konu yoksa ipucu verir', async () => {
    // Bugün: 10 D + 4 Y + 6 B = 20 soru, net 9.
    await addResult({ correct: 10, wrong: 4, blank: 6 })
    // 3 gün önce: 5 D + 1 Y = 6 soru, net 4,75.
    await addResult({
      correct: 5,
      wrong: 1,
      takenAt: toISODateTime(new Date(Date.now() - 3 * DAY_MS)),
    })
    // 10 gün önce: pencere dışı.
    await addResult({
      correct: 30,
      wrong: 0,
      takenAt: toISODateTime(new Date(Date.now() - 10 * DAY_MS)),
    })
    renderCard(services)

    await within(card()).findByText('Bugün', { selector: 'dt' })
    expect(statValue('Bugün')).toBe('20 soru')
    expect(statValue('Son 7 gün')).toBe('26 soru')
    expect(statValue('Toplam net')).toBe('13,75')
    expect(
      within(card()).getByText('Zayıf konular için bir konuda en az 20 soru çöz.'),
    ).toBeVisible()
    expect(within(card()).getByRole('link', { name: 'Analiz ekranı' })).toHaveAttribute(
      'href',
      ROUTES.analysis,
    )
  })

  it('en az 20 soru çözülen konuları en zayıftan başlayarak gösterir', async () => {
    await addResult({ topicId: derivative.id, correct: 8, wrong: 8, blank: 4 }) // %40 doğru
    await addResult({ topicId: limits.id, correct: 18, wrong: 2, blank: 0 }) // %90 doğru
    renderCard(services)

    const heading = await within(card()).findByRole('heading', { name: 'En zayıf konular' })
    expect(heading).toBeVisible()
    const items = within(card()).getAllByRole('listitem')
    expect(items).toHaveLength(2)
    expect(items[0]).toHaveTextContent('Türev')
    expect(items[0]).toHaveTextContent('Matematik')
    expect(items[0]).toHaveTextContent('%40 doğru')
    expect(items[1]).toHaveTextContent('Limit')
    expect(items[1]).toHaveTextContent('%90 doğru')
    expect(within(card()).queryByText(/en az 20 soru çöz/)).toBeNull()
  })

  it('eşiğin altındaki konuyu listeye almaz', async () => {
    await addResult({ topicId: derivative.id, correct: 2, wrong: 10, blank: 7 }) // 19 soru
    renderCard(services)

    expect(
      await within(card()).findByText('Zayıf konular için bir konuda en az 20 soru çöz.'),
    ).toBeVisible()
    expect(within(card()).queryByText('Türev')).toBeNull()
  })
})
