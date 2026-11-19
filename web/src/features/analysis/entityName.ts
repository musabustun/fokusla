/** Kullanıcı tanımlı ders/konu adlarının doğrulaması (saf). */

export const MAX_SUBJECT_NAME_LENGTH = 60
export const MAX_TOPIC_NAME_LENGTH = 80

export type NameValidation = { ok: true; name: string } | { ok: false; error: string }

/** Adı kırpar; boşsa veya `maxLength`'i aşıyorsa `label` ile Türkçe hata döner. */
export function validateEntityName(raw: string, label: string, maxLength: number): NameValidation {
  const name = raw.trim().replace(/\s+/g, ' ')
  if (name === '') return { ok: false, error: `${label} boş olamaz.` }
  if (name.length > maxLength) {
    return { ok: false, error: `${label} en fazla ${maxLength} karakter olabilir.` }
  }
  return { ok: true, name }
}
