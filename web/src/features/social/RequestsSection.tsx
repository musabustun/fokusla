import { useState } from 'react'
import { useServices, type FriendRequest } from '@/data'
import { Button, ListRow, ListSection } from '@/ui'
import { socialErrorMessage } from './socialErrors'

/** Gelen (kabul/ret) ve giden (geri çek) arkadaşlık istekleri. */
export function RequestsSection({ requests }: { requests: readonly FriendRequest[] }) {
  const { social } = useServices()
  const [busyId, setBusyId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  if (requests.length === 0) return null

  async function run(id: string, action: () => Promise<void>) {
    setBusyId(id)
    setError(null)
    try {
      await action()
    } catch (caught) {
      setError(socialErrorMessage(caught))
    } finally {
      setBusyId(null)
    }
  }

  return (
    <ListSection
      header="İstekler"
      footer={
        error ? (
          <span role="alert" className="text-danger">
            {error}
          </span>
        ) : undefined
      }
    >
      {requests.map((request) => {
        const name = `@${request.user.username}`
        const isBusy = busyId === request.id
        if (request.direction === 'incoming') {
          return (
            <ListRow
              key={request.id}
              title={name}
              subtitle="Seni arkadaş olarak eklemek istiyor"
              accessory={
                <span className="flex gap-1">
                  <Button
                    size="small"
                    variant="plain"
                    disabled={isBusy}
                    aria-label={`${name} isteğini reddet`}
                    onClick={() =>
                      run(request.id, () => social.respondToRequest(request.id, false))
                    }
                  >
                    Reddet
                  </Button>
                  <Button
                    size="small"
                    variant="tinted"
                    loading={isBusy}
                    aria-label={`${name} isteğini kabul et`}
                    onClick={() => run(request.id, () => social.respondToRequest(request.id, true))}
                  >
                    Kabul et
                  </Button>
                </span>
              }
            />
          )
        }
        return (
          <ListRow
            key={request.id}
            title={name}
            subtitle="Yanıt bekleniyor"
            accessory={
              <Button
                size="small"
                variant="plain"
                loading={isBusy}
                aria-label={`${name} isteğini geri çek`}
                onClick={() => run(request.id, () => social.cancelRequest(request.id))}
              >
                Geri çek
              </Button>
            }
          />
        )
      })}
    </ListSection>
  )
}
