import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { EmptyState } from './EmptyState'
import { ListRow } from './ListRow'
import { ListSection } from './ListSection'
import { ScreenHeader } from './ScreenHeader'

describe('ListSection + ListRow', () => {
  it('renders a labelled list of rows in every mode', async () => {
    const onClick = vi.fn()
    render(
      <ListSection header="Hakkında" footer="Ücretsiz ve reklamsız.">
        <ListRow title="Sürüm" value="0.1.0" />
        <ListRow title="Kaynak kodu" href="https://example.org" />
        <ListRow title="Tema" onClick={onClick} />
        <ListRow title="Kitaplar" render={(props) => <a href="/kitaplar" {...props} />} />
      </ListSection>,
    )
    const section = screen.getByRole('region', { name: 'Hakkında' })
    expect(section).toHaveTextContent('Ücretsiz ve reklamsız.')
    expect(screen.getAllByRole('listitem')).toHaveLength(4)
    expect(screen.getByText('0.1.0')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Kaynak kodu' })).toHaveAttribute(
      'href',
      'https://example.org',
    )
    expect(screen.getByRole('link', { name: 'Kitaplar' })).toHaveAttribute('href', '/kitaplar')
    await userEvent.click(screen.getByRole('button', { name: 'Tema' }))
    expect(onClick).toHaveBeenCalledOnce()
  })
})

describe('ScreenHeader and EmptyState', () => {
  it('renders an h1 title and an h2 empty-state title', () => {
    render(
      <>
        <ScreenHeader title="Odak" subtitle="Bugün" />
        <EmptyState title="Henüz oturum yok" message="Başlatınca burada görünecek." />
      </>,
    )
    expect(screen.getByRole('heading', { level: 1, name: 'Odak' })).toBeInTheDocument()
    expect(screen.getByRole('heading', { level: 2, name: 'Henüz oturum yok' })).toBeInTheDocument()
  })
})
