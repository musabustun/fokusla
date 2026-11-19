import { expect, test, type Page } from '@playwright/test'

/**
 * Analiz kritik akışı (iPhone ve iPad projelerinde çalışır):
 * test sonucu ekle → genel durumda, ders ve konu analizinde net görünür; düzenle → net güncellenir.
 */

async function onboardAs(page: Page, fieldLabel: RegExp) {
  await page.goto('/')
  await page.getByRole('button', { name: 'Başla' }).click()
  await page.getByRole('radio', { name: fieldLabel }).check()
  await page.getByRole('button', { name: 'Devam' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Temanı seç' })).toBeVisible()
  await page.getByRole('button', { name: 'Devam' }).click()
  await page.getByRole('button', { name: 'Şimdilik atla' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()
}

async function addTestResult(page: Page) {
  await page.getByRole('button', { name: 'Test ekle', exact: true }).click()
  const dialog = page.getByRole('dialog', { name: 'Test ekle' })
  await expect(dialog).toBeVisible()

  await dialog.getByRole('combobox', { name: 'Ders' }).selectOption({ label: 'TYT · Türkçe' })
  const topic = dialog.getByRole('combobox', { name: 'Konu' })
  await expect(topic.getByRole('option', { name: 'Paragrafta Yapı' })).toBeAttached()
  await topic.selectOption({ label: 'Paragrafta Yapı' })
  await dialog.getByRole('textbox', { name: 'Kitaptaki yer' }).fill('Test 3')
  await dialog.getByRole('spinbutton', { name: 'Soru sayısı' }).fill('20')
  await dialog.getByRole('spinbutton', { name: 'Doğru' }).fill('12')
  await dialog.getByRole('spinbutton', { name: 'Yanlış' }).fill('4')

  // Boş otomatik: 20 − 12 − 4 = 4 → net 12 − 4/4 = 11.
  await expect(dialog.getByRole('spinbutton', { name: 'Boş' })).toHaveValue('4')
  await expect(dialog.getByRole('status')).toContainText('Net: 11,00')

  await dialog.getByRole('button', { name: 'Kaydet' }).click()
  await expect(dialog).toBeHidden()
}

test('test sonucu eklenir ve konu analizinde net görünür', async ({ page }) => {
  await onboardAs(page, /Sayısal/)
  await page.goto('/analiz')
  await expect(page.getByRole('heading', { level: 1, name: 'Analiz' })).toBeVisible()
  await expect(page.getByRole('heading', { name: 'Henüz test kaydın yok' })).toBeVisible()

  await addTestResult(page)

  // Genel durum
  const overview = page.getByRole('region', { name: 'Genel durum' })
  await expect(overview).toContainText('11,00')
  await expect(overview).toContainText('%60')

  // Ders analizi: çalışılan konu neti, hiç çalışılmamış konu "Henüz test yok"
  await page.getByRole('link', { name: /^Türkçe/ }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Türkçe' })).toBeVisible()
  const topics = page.getByRole('region', { name: 'Konular' })
  const studied = topics.getByRole('link', { name: /Paragrafta Yapı/ })
  await expect(studied).toContainText('11,00 net')
  await expect(topics.getByRole('link', { name: /Sözcükte Anlam/ })).toContainText('Henüz test yok')

  // Konu analizi
  await studied.click()
  await expect(page.getByRole('heading', { level: 1, name: 'Paragrafta Yapı' })).toBeVisible()
  const tests = page.getByRole('region', { name: 'Testler' })
  await expect(tests).toContainText('11,00 net')
  await expect(tests).toContainText('12D 4Y 4B')

  // Kayıt kalıcıdır
  await page.reload()
  await expect(page.getByRole('region', { name: 'Testler' })).toContainText('11,00 net')
})

test('test sonucu düzenlenir ve silinir', async ({ page }) => {
  await onboardAs(page, /Eşit Ağırlık/)
  await page.goto('/analiz')
  await addTestResult(page)

  await page.getByRole('link', { name: /^Türkçe/ }).click()
  await page
    .getByRole('region', { name: 'Konular' })
    .getByRole('link', { name: /Paragrafta Yapı/ })
    .click()

  await page.getByRole('region', { name: 'Testler' }).getByRole('button').first().click()
  const dialog = page.getByRole('dialog', { name: 'Testi düzenle' })
  await dialog.getByRole('spinbutton', { name: 'Yanlış' }).fill('8')
  await dialog.getByRole('spinbutton', { name: 'Boş' }).fill('0')
  await dialog.getByRole('button', { name: 'Kaydet' }).click()
  await expect(dialog).toBeHidden()
  // 12 − 8/4 = 10
  await expect(page.getByRole('region', { name: 'Testler' })).toContainText('10,00 net')

  await page.getByRole('region', { name: 'Testler' }).getByRole('button').first().click()
  await page
    .getByRole('dialog', { name: 'Testi düzenle' })
    .getByRole('button', { name: 'Sil' })
    .click()
  await page.getByRole('button', { name: 'Evet, sil' }).click()
  await expect(page.getByRole('heading', { name: 'Bu konuda henüz test yok' })).toBeVisible()
})
