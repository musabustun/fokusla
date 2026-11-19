/** İskelette imzası belirlenmiş ama henüz yazılmamış saf fonksiyonlar bunu fırlatır. */
export class NotImplementedError extends Error {
  constructor(name: string) {
    super(`${name} henüz uygulanmadı`)
    this.name = 'NotImplementedError'
  }
}
