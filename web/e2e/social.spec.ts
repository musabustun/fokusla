import { expect, test, type Page } from '@playwright/test'

/**
 * Sosyal kritik akış (iPhone ve iPad projelerinde): Apple ile Giriş (mock) → kullanıcı adı →
 * arkadaş ekle (simüle edilen kullanıcı isteği kabul eder) → arkadaşın odasına katıl.
 * Gerçek ağ yok: MockSocialService simüle edilmiş kullanıcılarla çalışır.
 */

async function skipOnboarding(page: Page) {
  await page.goto('/')
  await page.getByRole('button', { name: 'Başla' }).click()
  await page.getByRole('radio', { name: /Sayısal/ }).check()
  await page.getByRole('button', { name: 'Devam' }).click()
  await page.getByRole('button', { name: 'Şimdilik atla' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()
}

async function signInAndPickUsername(page: Page, username: string) {
  await page.goto('/sosyal')
  await expect(page.getByRole('heading', { level: 1, name: 'Sosyal' })).toBeVisible()
  await expect(page.getByText(/Yalnızca kullanıcı adın ve çalışma süren paylaşılır/)).toBeVisible()
  await page.getByRole('button', { name: 'Apple ile Giriş' }).click()

  await expect(page.getByRole('heading', { name: 'Kullanıcı adını seç' })).toBeVisible()
  await page.getByLabel('Kullanıcı adı').fill(username)
  await page.getByRole('button', { name: 'Devam' }).click()
  await expect(page.getByRole('heading', { name: /Arkadaşlar \(\d+\)/ })).toBeVisible()
}

test('giriş → kullanıcı adı → arkadaş ekle → odaya katıl', async ({ page }) => {
  await skipOnboarding(page)
  await signInAndPickUsername(page, 'deneme_ogrenci')

  // Profil: kullanıcı adı ve davet kodu görünür.
  await expect(page.getByRole('button', { name: /Kullanıcı adı.*@deneme_ogrenci/ })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Davet kodunu kopyala' })).toBeVisible()

  // Kullanıcı adıyla arkadaş ekle.
  await page.getByRole('button', { name: 'Arkadaş ekle' }).click()
  const sheet = page.getByRole('dialog', { name: 'Arkadaş ekle' })
  await sheet.getByLabel('Kullanıcı adı').fill('deniz_ea')
  await sheet.getByRole('button', { name: 'İstek gönder' }).click()
  await expect(sheet).toBeHidden()

  // Giden istek görünür, simüle edilen kullanıcı kabul edince arkadaş listesine geçer.
  const friends = page.getByRole('region', { name: /^Arkadaşlar \(/ })
  await expect(friends.getByRole('button', { name: /@deniz_ea/ })).toBeVisible({
    timeout: 10_000,
  })

  // Arkadaşın odası listede belirir; katıl.
  await page.getByRole('button', { name: 'TYT Matematik odasına katıl' }).click()
  const members = page.getByRole('list', { name: 'Odadakiler' })
  await expect(members).toBeVisible()
  await expect(members.getByText('@deniz_ea')).toBeVisible()
  await expect(members.getByText('@deneme_ogrenci')).toBeVisible()
  await expect(page.getByRole('link', { name: "Odak'a git" }).first()).toBeVisible()

  // Odadan çık → tekrar lobi.
  await page.getByRole('button', { name: 'Odadan çık' }).click()
  await expect(page.getByRole('button', { name: 'Oda oluştur' })).toBeVisible()
})

test('gelen isteği kabul et ve görünürlüğü kapat', async ({ page }) => {
  await skipOnboarding(page)
  await signInAndPickUsername(page, 'ikinci_ogrenci')

  await page.getByRole('button', { name: '@zeynep2027 isteğini kabul et' }).click()
  const friends = page.getByRole('region', { name: /^Arkadaşlar \(/ })
  await expect(friends.getByRole('button', { name: /@zeynep2027/ })).toBeVisible()

  const visibility = page.getByRole('switch', { name: 'Sosyalde görün' })
  await expect(visibility).toHaveAttribute('aria-checked', 'true')
  await visibility.click()
  await expect(visibility).toHaveAttribute('aria-checked', 'false')
  await expect(page.getByText(/Şu an gizlisin/)).toBeVisible()

  // Oturum ve profil yeniden yüklemede korunur.
  await page.reload()
  await expect(page.getByRole('switch', { name: 'Sosyalde görün' })).toHaveAttribute(
    'aria-checked',
    'false',
  )
})
