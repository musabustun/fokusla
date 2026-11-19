import { expect, test, type Page } from '@playwright/test'

/**
 * Bugün ekranı kritik akışları (iPhone ve iPad projelerinde çalışır):
 *  1. Boş başlangıç → her kartın tek sonraki adımı görünür → Odak başlat → Bugün'e dön, canlı süre.
 *  2. Görev ekle → Bugün'de görünür → buradan tamamlanır / geri alınır, yeniden yüklemede kalıcı.
 * Saat `page.clock` ile yönetilir (gün ortası: gece yarısına taşmasın).
 */

const START_TIME = new Date('2026-11-18T10:00:00')
const ROUTINE = '30 dk paragraf'

async function completeOnboarding(page: Page) {
  await page.clock.install({ time: START_TIME })
  await page.goto('/')
  await expect(page).toHaveURL(/\/hos-geldin$/)
  await page.getByRole('button', { name: 'Başla' }).click()
  await page.getByRole('radio', { name: /Sayısal/ }).check()
  await page.getByRole('button', { name: 'Devam' }).click()
  await page.getByRole('button', { name: 'Şimdilik atla' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()
}

function card(page: Page, title: string) {
  return page.getByRole('region', { name: title, exact: true })
}

async function openToday(page: Page) {
  await page.getByRole('link', { name: 'Bugün', exact: true }).first().click()
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()
}

test('boş başlangıç → odak başlat → Bugün’de canlı süre görünür', async ({ page }) => {
  await completeOnboarding(page)

  // Başlık: selam ve alan.
  await expect(page.getByText('Günaydın')).toBeVisible()
  await expect(page.getByText('Sayısal alanı')).toBeVisible()

  // Her kartın boş durumu tek bir sonraki adıma yönlendirir.
  await expect(
    card(page, 'Bugünün görevleri').getByRole('link', { name: 'Görev ekle' }),
  ).toBeVisible()
  await expect(
    card(page, 'Son testler').getByRole('link', { name: 'İlk testini ekle' }),
  ).toBeVisible()
  await expect(card(page, 'Kitaplar').getByRole('link', { name: 'Kitap ekle' })).toBeVisible()

  const focus = card(page, 'Odak')
  await expect(focus.getByTestId('today-focus-total')).toHaveText('0 dk')
  await expect(focus.getByRole('list', { name: 'Son 7 gün' }).getByRole('listitem')).toHaveCount(7)

  await focus.getByRole('link', { name: 'Odak başlat' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Odak' })).toBeVisible()
  await page.getByRole('button', { name: 'Odak başlat' }).click()
  await expect(page.getByRole('timer', { name: 'Oturum süresi' })).toBeVisible()

  await page.clock.fastForward('12:00')
  await openToday(page)

  await expect(focus.getByRole('timer', { name: 'Oturum süresi' })).toHaveText(/^12:\d\d$/)
  await expect(focus.getByTestId('today-focus-total')).toHaveText('12 dk')
  await expect(focus.getByRole('link', { name: 'Devam et' })).toBeVisible()

  // Canlı: süre Bugün ekranında da akar.
  await page.clock.fastForward('03:00')
  await expect(focus.getByRole('timer', { name: 'Oturum süresi' })).toHaveText(/^15:\d\d$/)
  await expect(focus.getByTestId('today-focus-total')).toHaveText('15 dk')

  await focus.getByRole('link', { name: 'Devam et' }).click()
  await expect(page).toHaveURL(/\/odak$/)
})

test('görev eklenir → Bugün’de görünür → buradan tamamlanır ve geri alınır', async ({ page }) => {
  await completeOnboarding(page)

  await card(page, 'Bugünün görevleri').getByRole('link', { name: 'Görev ekle' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Görevler' })).toBeVisible()
  await page.getByRole('button', { name: 'Görev ekle' }).click()
  const dialog = page.getByRole('dialog', { name: 'Yeni görev' })
  await dialog.getByRole('radio', { name: 'Rutin' }).click()
  await dialog.getByLabel('Başlık').fill(ROUTINE)
  await dialog.getByRole('button', { name: 'Kaydet' }).click()
  await expect(dialog).toBeHidden()

  await openToday(page)
  const tasks = card(page, 'Bugünün görevleri')
  const check = tasks.getByRole('checkbox', { name: ROUTINE })
  await expect(check).toHaveAttribute('aria-checked', 'false')
  await expect(tasks).toContainText('0 / 1 tamamlandı')

  await check.click()
  await expect(check).toHaveAttribute('aria-checked', 'true')
  await expect(tasks).toContainText('1 / 1 tamamlandı')

  await page.reload()
  await expect(check).toHaveAttribute('aria-checked', 'true')

  // Görevler ekranı da aynı tamamlamayı görür.
  await tasks.getByRole('link', { name: 'Tüm görevler' }).click()
  await expect(
    page.getByRole('region', { name: 'Rutinler' }).getByRole('checkbox', { name: ROUTINE }),
  ).toHaveAttribute('aria-checked', 'true')

  await openToday(page)
  await check.click()
  await expect(check).toHaveAttribute('aria-checked', 'false')
  await expect(tasks).toContainText('0 / 1 tamamlandı')
})
