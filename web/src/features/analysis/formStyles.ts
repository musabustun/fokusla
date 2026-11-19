/** Analiz formlarının (sheet'ler) ortak giriş stilleri ve erişilebilirlik nitelikleri. */
import { inputStyles } from '@/ui'

/** Metin/sayı/tarih girişi ve <select> için ortak sınıf (≥44px, yalnızca token sınıfları). */
export const INPUT_CLASS = inputStyles()

/** Alan hatasının DOM id'si. */
export function errorIdFor(id: string): string {
  return `${id}-error`
}

/** Giriş öğesine verilecek id + aria-invalid + aria-describedby. */
export function fieldA11y(
  id: string,
  error: string | undefined,
): { id: string; 'aria-invalid'?: true; 'aria-describedby'?: string } {
  return error ? { id, 'aria-invalid': true, 'aria-describedby': errorIdFor(id) } : { id }
}

/** Kaydetme/silme beklenmedik şekilde başarısız olursa gösterilen mesaj. */
export const SAVE_FAILED_MESSAGE = 'Kaydedilemedi. Lütfen tekrar dene.'
export const DELETE_FAILED_MESSAGE = 'Silinemedi. Lütfen tekrar dene.'
