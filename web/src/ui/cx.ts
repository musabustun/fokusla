/** Koşullu sınıf adlarını birleştirir (clsx'in küçük karşılığı). */
export function cx(...classes: (string | false | null | undefined)[]): string {
  return classes.filter(Boolean).join(' ')
}
