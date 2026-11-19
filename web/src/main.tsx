import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from '@/app/App'
import { createServices } from '@/data'
import './index.css'

const rootElement = document.getElementById('root')
if (!rootElement) {
  throw new Error('#root bulunamadı')
}

const services = createServices()

createRoot(rootElement).render(
  <StrictMode>
    <App services={services} />
  </StrictMode>,
)
