import { useState } from 'react'
import { RouterProvider } from 'react-router'
import { ServicesProvider, type AppServices } from '@/data'
import { ThemeProvider } from '@/ui'
import { createAppRouter } from './router'

interface AppProps {
  services: AppServices
}

export function App({ services }: AppProps) {
  const [router] = useState(createAppRouter)
  return (
    <ServicesProvider services={services}>
      <ThemeProvider>
        <RouterProvider router={router} />
      </ThemeProvider>
    </ServicesProvider>
  )
}
