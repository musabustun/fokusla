import { expect, test, type Page } from '@playwright/test'

/**
 * Duman testi: onboarding uçtan uca (iPhone ve iPad projelerinde çalışır).
 * Hoş geldin → alan seçimi → Temanı seç → Apple ile Giriş (mock) / Şimdilik atla → Bugün.
 * İkinci açılışta onboarding gösterilmez.
 */

async function goToThemeStep(page: Page, fieldLabel: RegExp) {
  await page.goto('/')
  await expect(page).toHaveURL(/\/hos-geldin$/)
  await expect(page.getByRole('heading', { level: 1, name: /Fokus/ })).toBeVisible()
  await page.getByRole('button', { name: 'Başla' }).click()

  await expect(page.getByRole('heading', { level: 1, name: /alanın/i })).toBeVisible()
  await page.getByRole('radio', { name: fieldLabel }).check()
  await page.getByRole('button', { name: 'Devam' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Temanı seç' })).toBeVisible()
}

async function completeWelcomeAndField(page: Page, fieldLabel: RegExp) {
  await goToThemeStep(page, fieldLabel)
  await page.getByRole('button', { name: 'Devam' }).click()
  await expect(page.getByRole('button', { name: 'Şimdilik atla' })).toBeVisible()
}

test('şimdilik atla ile onboarding tamamlanır ve tekrar gösterilmez', async ({ page }) => {
  await completeWelcomeAndField(page, /Eşit Ağırlık/)

  await page.getByRole('button', { name: 'Şimdilik atla' }).click()

  await expect(page).toHaveURL(/\/$/)
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()
  await expect(page.getByRole('navigation', { name: 'Ana gezinme' })).toBeVisible()

  await page.reload()
  await expect(page).toHaveURL(/\/$/)
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()
})

test('Apple ile Giriş (mock) ile onboarding tamamlanır', async ({ page }) => {
  await completeWelcomeAndField(page, /Sayısal/)

  await page.getByRole('button', { name: /Apple ile Giriş/ }).click()

  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()

  await page.getByRole('link', { name: 'Ayarlar' }).first().click()
  await expect(page.getByRole('heading', { level: 1, name: 'Ayarlar' })).toBeVisible()
})

test('gezinme tüm modül ekranlarına ulaşır', async ({ page }) => {
  await completeWelcomeAndField(page, /Sözel/)
  await page.getByRole('button', { name: 'Şimdilik atla' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()

  for (const [path, title] of [
    ['/odak', 'Odak'],
    ['/analiz', 'Analiz'],
    ['/kitaplar', 'Kitaplar'],
    ['/gorevler', 'Görevler'],
    ['/sosyal', 'Sosyal'],
    ['/ayarlar', 'Ayarlar'],
  ] as const) {
    await page.goto(path)
    await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
  }
})

test('tema adımında seçilen palet anında uygulanır ve kalıcıdır', async ({ page }) => {
  await goToThemeStep(page, /Sayısal/)

  await page.getByRole('radio', { name: 'Yaban mersini' }).check()
  await expect(page.locator('html')).toHaveAttribute('data-palette', 'blueberry')

  await page.getByRole('button', { name: 'Devam' }).click()
  await page.getByRole('button', { name: 'Şimdilik atla' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()
  await expect(page.locator('html')).toHaveAttribute('data-palette', 'blueberry')

  await page.reload()
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()
  await expect(page.locator('html')).toHaveAttribute('data-palette', 'blueberry')
})

test('tema adımında Geri alan seçimine döner', async ({ page }) => {
  await goToThemeStep(page, /Sayısal/)

  await page.getByRole('button', { name: 'Geri' }).click()

  await expect(page.getByRole('heading', { level: 1, name: /alanın/i })).toBeVisible()
  await expect(page.getByRole('radio', { name: /Sayısal/ })).toBeChecked()
})
