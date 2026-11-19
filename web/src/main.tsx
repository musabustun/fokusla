import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from '@/app/App'
import { yksCurriculum } from '@/curriculum'
import { createServices, ensureCurriculumSeeded } from '@/data'
import './index.css'

const rootElement = document.getElementById('root')
if (!rootElement) {
  throw new Error('#root bulunamadı')
}

const services = createServices()

// Müfredat kataloğu idempotent tohumlanır; ekranlar canlı sorgularla güncellenir.
ensureCurriculumSeeded(services.repositories, yksCurriculum).catch((error: unknown) => {
  console.error('Müfredat yüklenemedi', error)
})

createRoot(rootElement).render(
  <StrictMode>
    <App services={services} />
  </StrictMode>,
)
