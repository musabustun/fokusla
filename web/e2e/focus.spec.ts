import { expect, test, type Page } from '@playwright/test'

/**
 * Odak modülü kritik akışı (iPhone ve iPad projelerinde çalışır).
 * Saat `page.clock` ile yönetilir: zaman doğal akar, `fastForward` ile ileri sarılır.
 * Süreler zaman damgalarından hesaplandığı için birkaç saniyelik gerçek gecikme yalnızca
 * saniye hanesini etkiler; doğrulamalar dakika düzeyindedir.
 */

/** Gün ortası: testin gece yarısına taşmaması için. */
const START_TIME = new Date('2026-11-18T10:00:00')

async function skipOnboardingAndOpenFocus(page: Page) {
  await page.clock.install({ time: START_TIME })
  await page.goto('/')
  await expect(page).toHaveURL(/\/hos-geldin$/)
  await page.getByRole('button', { name: 'Başla' }).click()
  await page.getByRole('radio', { name: /Sayısal/ }).check()
  await page.getByRole('button', { name: 'Devam' }).click()
  await page.getByRole('button', { name: 'Şimdilik atla' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()

  await page.getByRole('link', { name: 'Odak' }).first().click()
  await expect(page.getByRole('heading', { level: 1, name: 'Odak' })).toBeVisible()
}

function focusTimer(page: Page) {
  return page.getByRole('timer', { name: 'Oturum süresi' })
}

function breakTimer(page: Page) {
  return page.getByRole('timer', { name: 'Mola süresi' })
}

test('başlat → mola → devam → bitir → istatistik', async ({ page }) => {
  await skipOnboardingAndOpenFocus(page)

  await page.getByRole('button', { name: 'Odak başlat' }).click()
  await expect(focusTimer(page)).toBeVisible()
  await expect(page.getByRole('status')).toHaveText('Odak başladı')

  await page.clock.fastForward('25:00')
  await expect(focusTimer(page)).toHaveText(/^25:\d\d$/)
  await expect(page.getByTestId('today-total')).toHaveText('25 dk')

  // Yenileme sonrası açık oturum kaldığı yerden doğru süreyle devam eder.
  await page.reload()
  await expect(focusTimer(page)).toHaveText(/^25:\d\d$/)

  await page.getByRole('button', { name: 'Mola ver' }).click()
  await expect(breakTimer(page)).toBeVisible()
  await expect(page.getByRole('status')).toHaveText('Mola başladı')
  await page.clock.fastForward('05:00')
  await expect(breakTimer(page)).toHaveText(/^05:\d\d$/)
  // Molada bugünkü toplam artmaz.
  await expect(page.getByTestId('today-total')).toHaveText('25 dk')

  await page.getByRole('button', { name: 'Devam et' }).click()
  await expect(focusTimer(page)).toHaveText(/^25:\d\d$/)
  await expect(page.getByRole('status')).toHaveText('Odağa devam edildi')

  await page.clock.fastForward('10:00')
  await expect(focusTimer(page)).toHaveText(/^35:\d\d$/)
  await expect(page.getByTestId('today-total')).toHaveText('35 dk')

  await page.getByRole('button', { name: 'Bitir' }).click()
  const summary = page.getByRole('dialog', { name: 'Oturum özeti' })
  await expect(summary).toBeVisible()
  const summaryRow = (title: string) => summary.getByRole('listitem').filter({ hasText: title })
  await expect(summaryRow('Toplam odak')).toContainText('35 dk')
  await expect(summaryRow('Mola sayısı')).toContainText('1')
  await expect(summaryRow('Toplam mola')).toContainText('5 dk')
  await summary.getByRole('button', { name: 'Tamam' }).click()
  await expect(summary).toBeHidden()
  await expect(page.getByRole('status')).toHaveText('Oturum bitti')

  // Boşta: yeniden başlatılabilir, istatistikler güncel.
  await expect(page.getByRole('button', { name: 'Odak başlat' })).toBeVisible()
  // Odak segmentleri 25 ve 10 dk → ortalama 17,5 dk.
  await expect(page.getByRole('region', { name: 'Ortalama kesintisiz odak' })).toContainText(
    '17 dk',
  )
  await expect(page.getByRole('region', { name: 'Ortalama mola' })).toContainText('5 dk')
  await expect(page.getByTestId('today-total')).toHaveText('35 dk')
  const week = page.getByRole('list', { name: 'Son 7 gün' })
  await expect(week.getByRole('listitem')).toHaveCount(7)
  await expect(week.getByRole('listitem').last()).toContainText('35 dk')

  const history = page.getByRole('region', { name: 'Geçmiş oturumlar' })
  await expect(history.getByRole('listitem')).toHaveCount(1)
  await expect(history.getByRole('listitem').first()).toContainText('Ders seçilmedi')
  await expect(history.getByRole('listitem').first()).toContainText('35 dk')
})

test('uzun molada uyarı çıkar, oturum kendiliğinden bitmez; ders geçmişte görünür', async ({
  page,
}) => {
  await skipOnboardingAndOpenFocus(page)

  const subjectSelect = page.getByLabel('Ders (isteğe bağlı)')
  await expect(subjectSelect.locator('option')).not.toHaveCount(1)
  const subjectName = (await subjectSelect.locator('option').nth(1).textContent())?.trim() ?? ''
  expect(subjectName).not.toBe('')
  await subjectSelect.selectOption({ label: subjectName })
  await expect(page.getByLabel('Konu (isteğe bağlı)')).toBeEnabled()

  await page.getByRole('button', { name: 'Odak başlat' }).click()
  await page.clock.fastForward('20:00')
  await page.getByRole('button', { name: 'Mola ver' }).click()
  await expect(breakTimer(page)).toBeVisible()

  await page.clock.fastForward('31:00')
  const alert = page.getByRole('alert').filter({ hasText: 'Molan uzadı' })
  await expect(alert).toBeVisible()
  // Oturum hâlâ açık: mola sayacı sürüyor.
  await expect(breakTimer(page)).toHaveText(/^3\d:\d\d$/)

  await alert.getByRole('button', { name: 'Oturumu bitir' }).click()
  const summary = page.getByRole('dialog', { name: 'Oturum özeti' })
  await expect(summary).toBeVisible()
  await expect(summary.getByRole('listitem').filter({ hasText: 'Toplam odak' })).toContainText(
    '20 dk',
  )
  await summary.getByRole('button', { name: 'Tamam' }).click()

  const history = page.getByRole('region', { name: 'Geçmiş oturumlar' })
  await expect(history.getByRole('listitem').first()).toContainText(subjectName)
})
