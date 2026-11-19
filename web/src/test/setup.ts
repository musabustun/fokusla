import '@testing-library/jest-dom/vitest'
import 'fake-indexeddb/auto'
import { cleanup, configure } from '@testing-library/react'
import { afterEach } from 'vitest'

// findBy*/waitFor varsayılanı 1 sn; yük altında çok adımlı akışlarda yetmiyordu.
configure({ asyncUtilTimeout: 3_000 })

afterEach(() => {
  cleanup()
})
