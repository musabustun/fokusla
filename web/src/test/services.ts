/**
 * Testler için gerçek (Dexie + fake-indexeddb) servisler. Her çağrı benzersiz bir veritabanı
 * açar; `dispose` ile silinir. Feature testleri Dexie'yi doğrudan import etmek yerine bunu kullanır:
 *
 *   let ctx: TestServices
 *   beforeEach(() => { ctx = createTestServices() })
 *   afterEach(() => ctx.dispose())
 */
import Dexie from 'dexie'
import { createServices, type AppServices, type CreateServicesOptions } from '@/data'

export interface TestServices {
  services: AppServices
  dispose: () => Promise<void>
}

export function createTestServices(
  options: Omit<CreateServicesOptions, 'dbName'> = {},
): TestServices {
  const dbName = `test-${crypto.randomUUID()}`
  const services = createServices({
    authDelayMs: 0,
    syncDelayMs: 0,
    ...options,
    social: { delayMs: 0, tickMs: 0, responseDelayMs: 0, ...options.social },
    dbName,
  })
  return { services, dispose: () => Dexie.delete(dbName) }
}
