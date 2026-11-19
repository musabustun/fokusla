import { expect, test, type Page } from '@playwright/test'

/**
 * Görevler kritik akışı (iPhone ve iPad projelerinde çalışır):
 * rutin + bugün teslim ödev ekle → Bugün görünümünde gör → tamamla → yeniden yüklemede kalıcı →
 * ayrıntıyı aç (iPhone: sheet, iPad: yan panel).
 */

const ROUTINE = '50 paragraf sorusu'
const ASSIGNMENT = 'Fizik ödev föyü 3'

async function completeOnboarding(page: Page) {
  await page.goto('/')
  await expect(page).toHaveURL(/\/hos-geldin$/)
  await page.getByRole('button', { name: 'Başla' }).click()
  await page.getByRole('radio', { name: /Sayısal/ }).check()
  await page.getByRole('button', { name: 'Devam' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Temanı seç' })).toBeVisible()
  await page.getByRole('button', { name: 'Devam' }).click()
  await page.getByRole('button', { name: 'Şimdilik atla' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Bugün' })).toBeVisible()
}

async function addTask(
  page: Page,
  {
    kind,
    title,
    target,
    unit,
  }: { kind: 'Rutin' | 'Ödev'; title: string; target?: string; unit?: string },
) {
  await page.getByRole('button', { name: 'Görev ekle' }).click()
  const dialog = page.getByRole('dialog', { name: 'Yeni görev' })
  await expect(dialog).toBeVisible()
  await dialog.getByRole('radio', { name: kind }).click()
  await dialog.getByLabel('Başlık').fill(title)
  if (target) await dialog.getByLabel('Hedef miktar').fill(target)
  if (unit) await dialog.getByLabel('Birim').fill(unit)
  await dialog.getByRole('button', { name: 'Kaydet' }).click()
  await expect(dialog).toBeHidden()
}

test('rutin ve ödev eklenir, tamamlanır, kalıcıdır ve ayrıntısı açılır', async ({ page }) => {
  await completeOnboarding(page)
  await page.goto('/gorevler')
  await expect(page.getByRole('heading', { level: 1, name: 'Görevler' })).toBeVisible()

  await addTask(page, { kind: 'Rutin', title: ROUTINE, target: '50', unit: 'soru' })
  await addTask(page, { kind: 'Ödev', title: ASSIGNMENT })

  const routines = page.getByRole('region', { name: 'Rutinler' })
  const dueToday = page.getByRole('region', { name: 'Bugün teslim' })
  const routineCheck = routines.getByRole('checkbox', { name: ROUTINE })
  const assignmentCheck = dueToday.getByRole('checkbox', { name: ASSIGNMENT })
  await expect(routineCheck).toBeVisible()
  await expect(routines.getByText('50 soru')).toBeVisible()
  await expect(assignmentCheck).toBeVisible()

  await routineCheck.click()
  await assignmentCheck.click()
  await expect(routineCheck).toHaveAttribute('aria-checked', 'true')
  await expect(assignmentCheck).toHaveAttribute('aria-checked', 'true')

  await page.reload()
  await expect(page.getByRole('checkbox', { name: ROUTINE })).toHaveAttribute(
    'aria-checked',
    'true',
  )
  await expect(page.getByRole('checkbox', { name: ASSIGNMENT })).toHaveAttribute(
    'aria-checked',
    'true',
  )

  await page.getByRole('button', { name: `Ayrıntılar: ${ROUTINE}` }).click()
  const isWide = (page.viewportSize()?.width ?? 0) >= 1024
  const container = isWide
    ? page.getByRole('complementary', { name: 'Görev ayrıntıları' })
    : page.getByRole('dialog', { name: ROUTINE })
  await expect(container.getByRole('heading', { name: ROUTINE })).toBeVisible()
  await expect(
    container.getByRole('progressbar', { name: 'Son 7 gün tamamlama oranı' }),
  ).toHaveAttribute('aria-valuenow', '100')
  await expect(container.getByRole('button', { name: 'Geri al' })).toBeVisible()
})
