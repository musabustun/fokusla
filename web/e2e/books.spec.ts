import { expect, test, type Page } from '@playwright/test'

/**
 * Kitap takibi kritik akışı (iPhone ve iPad projelerinde çalışır):
 * kitap ekle → ilerleme gir → yüzde güncellenir → toplama ulaşınca "Tamamlandı".
 * iPhone'da liste → detay ayrı ekranlardır; iPad'de (≥1024px) yan yana durur.
 */

async function skipOnboarding(page: Page) {
  await page.goto('/')
  await page.getByRole('button', { name: 'Başla' }).click()
  await page.getByRole('radio', { name: /Sayısal/ }).check()
  await page.getByRole('button', { name: 'Devam' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Temanı seç' })).toBeVisible()
  await page.getByRole('button', { name: 'Devam' }).click()
  await page.getByRole('button', { name: 'Şimdilik atla' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()
}

async function addBook(page: Page, title: string, total: number) {
  await page.goto('/kitaplar')
  await expect(page.getByRole('heading', { level: 1, name: 'Kitaplar' })).toBeVisible()
  await page.getByRole('button', { name: 'Kitap ekle' }).click()

  const sheet = page.getByRole('dialog', { name: 'Kitap ekle' })
  await sheet.getByLabel('Kitap adı').fill(title)
  await sheet.getByLabel('Yayınevi').fill('Örnek Yayınları')
  await sheet.getByRole('radio', { name: 'Test' }).check()
  await sheet.getByLabel('Toplam').fill(String(total))
  await sheet.getByRole('button', { name: 'Kaydet' }).click()

  await expect(page).toHaveURL(/\/kitaplar\/[0-9a-f-]{36}$/)
  await expect(page.getByRole('heading', { name: title })).toBeVisible()
}

async function enterProgress(page: Page, reached: number) {
  await page.getByRole('button', { name: 'İlerleme gir' }).click()
  const sheet = page.getByRole('dialog', { name: 'İlerleme gir' })
  await sheet.getByLabel('Ulaştığın test').fill(String(reached))
  await sheet.getByRole('button', { name: 'Kaydet' }).click()
  await expect(sheet).toBeHidden()
}

test('kitap ekle → ilerleme gir → yüzde güncellenir', async ({ page }) => {
  await skipOnboarding(page)
  await addBook(page, 'Limit TYT Matematik', 120)

  const progress = page.getByRole('progressbar', { name: 'Kitap ilerlemesi' })
  await expect(progress).toHaveAttribute('aria-valuenow', '0')

  await enterProgress(page, 30)
  await expect(progress).toHaveAttribute('aria-valuenow', '25')
  await expect(page.getByText('%25').first()).toBeVisible()
  await expect(page.getByRole('listitem').filter({ hasText: 'Test 30' }).first()).toBeVisible()

  // Liste de güncel yüzdeyi gösterir (iPhone: ayrı ekran; iPad: soldaki sütun).
  await page.goto('/kitaplar')
  const row = page.getByRole('link', { name: /Limit TYT Matematik/ })
  await expect(row).toBeVisible()
  await expect(row).toContainText('%25')

  // Veri cihazda kalır: yeniden yüklemede ilerleme korunur.
  await page.reload()
  await expect(page.getByRole('link', { name: /Limit TYT Matematik/ })).toContainText('%25')
})

test('toplama ulaşan kitap tamamlandı olur ve bitenlere geçer', async ({ page }) => {
  await skipOnboarding(page)
  await addBook(page, 'Paragraf Soru Bankası', 40)

  await enterProgress(page, 40)
  await expect(page.getByRole('progressbar', { name: 'Kitap ilerlemesi' })).toHaveAttribute(
    'aria-valuenow',
    '100',
  )
  await expect(page.getByText('Tamamlandı').first()).toBeVisible()

  await page.goto('/kitaplar')
  await expect(page.getByRole('link', { name: /Paragraf Soru Bankası/ })).toHaveCount(0)
  await page.getByRole('radio', { name: /Biten/ }).click()
  await expect(page.getByRole('link', { name: /Paragraf Soru Bankası/ })).toBeVisible()
})
