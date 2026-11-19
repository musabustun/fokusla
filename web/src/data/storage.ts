/**
 * localStorage'a güvenli erişim. Gizli mod, kota veya devre dışı depolama durumlarında
 * hata FIRLATMAZ; okuma null döner, yazma sessizce atlanır (konsola uyarı yazılır).
 */
export type KeyValueStorage = Pick<Storage, 'getItem' | 'setItem' | 'removeItem'>

/** Tarayıcı localStorage'ı; erişilemiyorsa null. */
export function defaultStorage(): KeyValueStorage | null {
  try {
    return globalThis.localStorage ?? null
  } catch {
    return null
  }
}

export function safeGetItem(storage: KeyValueStorage | null, key: string): string | null {
  if (!storage) return null
  try {
    return storage.getItem(key)
  } catch (error) {
    console.warn(`Depolamadan okunamadı (${key})`, error)
    return null
  }
}

export function safeSetItem(storage: KeyValueStorage | null, key: string, value: string): void {
  if (!storage) return
  try {
    storage.setItem(key, value)
  } catch (error) {
    console.warn(`Depolamaya yazılamadı (${key})`, error)
  }
}

export function safeRemoveItem(storage: KeyValueStorage | null, key: string): void {
  if (!storage) return
  try {
    storage.removeItem(key)
  } catch (error) {
    console.warn(`Depolamadan silinemedi (${key})`, error)
  }
}

/** ms > 0 ise bekler; 0 ise hemen çözülür (testler için). */
export function wait(ms: number): Promise<void> {
  return ms > 0 ? new Promise((resolve) => setTimeout(resolve, ms)) : Promise.resolve()
}
