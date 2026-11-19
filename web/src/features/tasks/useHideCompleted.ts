import { useCallback, useState } from 'react'

/** Cihaza özel tercih (senkronize edilmez). SwiftUI: `@AppStorage("fokus.tasks.hideCompleted")`. */
export const HIDE_COMPLETED_STORAGE_KEY = 'fokus.tasks.hideCompleted'

function readStored(): boolean {
  try {
    return localStorage.getItem(HIDE_COMPLETED_STORAGE_KEY) === 'true'
  } catch {
    // Depolama kapalıysa (gizli mod vb.) varsayılan: göster.
    return false
  }
}

/** "Tamamlananları gizle" tercihi; localStorage'da saklanır. */
export function useHideCompleted(): [boolean, (value: boolean) => void] {
  const [hideCompleted, setHideCompleted] = useState(readStored)
  const update = useCallback((value: boolean) => {
    setHideCompleted(value)
    try {
      localStorage.setItem(HIDE_COMPLETED_STORAGE_KEY, String(value))
    } catch (error) {
      console.warn('Tamamlananları gizle tercihi kaydedilemedi', error)
    }
  }, [])
  return [hideCompleted, update]
}
