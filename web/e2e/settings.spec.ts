import { expect, test, type Page } from '@playwright/test'

/**
 * Ayarlar duman testleri (iPhone ve iPad projeleri): alan/tema değiştirme, giriş/çıkış,
 * dışa aktarma ve çift onaylı veri silme.
 */

async function onboardAndOpenSettings(page: Page) {
  await page.goto('/')
  await expect(page).toHaveURL(/\/hos-geldin$/)
  await page.getByRole('button', { name: 'Başla' }).click()
  await page.getByRole('radio', { name: /Sayısal/ }).check()
  await page.getByRole('button', { name: 'Devam' }).click()
  await page.getByRole('button', { name: 'Şimdilik atla' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()
  await page.goto('/ayarlar')
  await expect(page.getByRole('heading', { level: 1, name: 'Ayarlar' })).toBeVisible()
}

test('YKS alanı değişir ve yeniden açılışta kalır', async ({ page }) => {
  await onboardAndOpenSettings(page)
  await expect(page.getByRole('button', { name: /YKS alanı.*Sayısal/ })).toBeVisible()

  await page.getByRole('button', { name: /YKS alanı/ }).click()
  const dialog = page.getByRole('dialog', { name: 'YKS alanı' })
  await dialog.getByRole('radio', { name: /Sözel/ }).click()
  await expect(dialog).toBeHidden()
  await expect(page.getByRole('button', { name: /YKS alanı.*Sözel/ })).toBeVisible()

  await page.reload()
  await expect(page.getByRole('button', { name: /YKS alanı.*Sözel/ })).toBeVisible()
})

test('tema koyuya geçer ve kalıcıdır', async ({ page }) => {
  await onboardAndOpenSettings(page)
  await page.getByRole('radio', { name: 'Koyu' }).click()
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
  await page.reload()
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
  await expect(page.getByRole('radio', { name: 'Koyu' })).toBeChecked()
})

test('Apple ile Giriş, senkron ve çıkış akışı', async ({ page }) => {
  await onboardAndOpenSettings(page)

  const sync = page.getByRole('switch', { name: 'iCloud senkronu' })
  await expect(sync).toBeDisabled()
  await expect(page.getByText(/giriş yapmadın/)).toBeVisible()

  await page.getByRole('button', { name: /Apple ile Giriş/ }).click()
  await expect(page.getByRole('button', { name: 'Çıkış yap' })).toBeVisible()
  await expect(sync).toBeEnabled()

  await sync.click()
  await expect(sync).toBeChecked()
  await expect(page.getByText(/Son senkron:/)).toBeVisible()

  await page.getByRole('button', { name: 'Çıkış yap' }).click()
  await expect(page.getByRole('button', { name: /Apple ile Giriş/ })).toBeVisible()
  await expect(sync).toBeDisabled()
  await expect(sync).not.toBeChecked()
})

test('veriler JSON olarak indirilir', async ({ page }) => {
  await onboardAndOpenSettings(page)
  const download = page.waitForEvent('download')
  await page.getByRole('button', { name: /Verileri dışa aktar/ }).click()
  expect((await download).suggestedFilename()).toMatch(/^fokus-yedek-\d{4}-\d{2}-\d{2}\.json$/)
})

test('tüm veriler iki onayla silinir ve onboarding açılır', async ({ page }) => {
  await onboardAndOpenSettings(page)

  await page.getByRole('button', { name: 'Tüm verileri sil' }).click()
  await page
    .getByRole('dialog', { name: 'Tüm veriler silinsin mi?' })
    .getByRole('button', { name: 'Devam' })
    .click()
  await page
    .getByRole('dialog', { name: 'Emin misin?' })
    .getByRole('button', { name: 'Her şeyi kalıcı olarak sil' })
    .click()

  await expect(page).toHaveURL(/\/hos-geldin$/)
  await expect(page.getByRole('heading', { level: 1, name: /Fokus/ })).toBeVisible()
})
