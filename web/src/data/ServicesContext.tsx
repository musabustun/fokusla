import { createContext, useContext, type ReactNode } from 'react'
import type { AppServices } from './services'

const ServicesContext = createContext<AppServices | null>(null)

interface ServicesProviderProps {
  services: AppServices
  children: ReactNode
}

export function ServicesProvider({ services, children }: ServicesProviderProps) {
  return <ServicesContext.Provider value={services}>{children}</ServicesContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export function useServices(): AppServices {
  const services = useContext(ServicesContext)
  if (!services) {
    throw new Error('useServices bir <ServicesProvider> içinde kullanılmalı')
  }
  return services
}
