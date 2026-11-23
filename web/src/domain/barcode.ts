/**
 * Barkod normalleştirme (saf fonksiyonlar). Kitap barkodları EAN-13 (ISBN-13 dahil) biçimine
 * çevrilir; kütüphane araması ve kayıt hep bu biçimle yapılır.
 * Swift karşılığı: `FokusDomain/Barcode.swift` (aynı davranış, aynı test vakaları).
 */

/** EAN-13 sağlama basamağı: ilk 12 hane, ağırlıklar 1-3-1-3… */
function ean13CheckDigit(first12: string): number {
  let sum = 0
  for (let i = 0; i < 12; i += 1) {
    sum += Number(first12[i]) * (i % 2 === 0 ? 1 : 3)
  }
  return (10 - (sum % 10)) % 10
}

/** 13 haneli, sağlaması doğru EAN-13 mü? */
export function isValidEan13(value: string): boolean {
  if (!/^\d{13}$/.test(value)) return false
  return ean13CheckDigit(value.slice(0, 12)) === Number(value[12])
}

/**
 * ISBN-10'u (son karakter X olabilir) EAN-13'e çevirir: `978` öneki + ilk 9 hane + yeni sağlama.
 * ISBN-10 sağlaması geçersizse null.
 */
export function isbn10ToEan13(value: string): string | null {
  const isbn = value.toUpperCase()
  if (!/^\d{9}[\dX]$/.test(isbn)) return null
  let sum = 0
  for (let i = 0; i < 10; i += 1) {
    const digit = isbn[i] === 'X' ? 10 : Number(isbn[i])
    sum += digit * (10 - i)
  }
  if (sum % 11 !== 0) return null
  const first12 = `978${isbn.slice(0, 9)}`
  return `${first12}${ean13CheckDigit(first12)}`
}

/** 12 haneli UPC-A sağlaması (ağırlıklar 3-1-3-1…, son hane sağlama). */
function isValidUpcA(value: string): boolean {
  if (!/^\d{12}$/.test(value)) return false
  let sum = 0
  for (let i = 0; i < 11; i += 1) {
    sum += Number(value[i]) * (i % 2 === 0 ? 3 : 1)
  }
  return (10 - (sum % 10)) % 10 === Number(value[11])
}

/**
 * Ham barkod metnini (boşluk/tire içerebilir) EAN-13'e çevirir; geçersizse null.
 * - 13 hane geçerli EAN-13 → aynen
 * - 10 karakter geçerli ISBN-10 → `978` önekli EAN-13
 * - 12 hane geçerli UPC-A → başına `0` eklenmiş EAN-13
 */
export function normalizeBarcode(raw: string): string | null {
  const cleaned = raw.replace(/[\s-]/g, '')
  if (cleaned.length === 13) return isValidEan13(cleaned) ? cleaned : null
  if (cleaned.length === 10) return isbn10ToEan13(cleaned)
  if (cleaned.length === 12) return isValidUpcA(cleaned) ? `0${cleaned}` : null
  return null
}
