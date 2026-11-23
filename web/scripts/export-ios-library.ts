/**
 * Web kitap kataloğunu iOS'a aktarır (`npm run export:ios-library`):
 *  - ios/FokusKit/Sources/FokusData/Resources/book-library.json
 * Vite modül çalıştırıcısı üzerinden çalışır; `@/` takma adı vite.config.ts'ten gelir.
 */
import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { runnerImport } from 'vite'
import type { BookLibrary } from '../src/library/types'

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const out = resolve(webRoot, '../ios/FokusKit/Sources/FokusData/Resources/book-library.json')

async function load<T>(path: string): Promise<T> {
  const { module } = await runnerImport<T>(resolve(webRoot, path), { root: webRoot })
  return module
}

const { bookLibrary } = await load<{ bookLibrary: BookLibrary }>('src/library/books.ts')
const { toIosLibraryJson } = await load<{
  toIosLibraryJson: (library: BookLibrary) => BookLibrary
}>('src/library/iosExport.ts')

const catalog = toIosLibraryJson(bookLibrary)
mkdirSync(dirname(out), { recursive: true })
writeFileSync(out, `${JSON.stringify(catalog, null, 2)}\n`)
process.stdout.write(`${catalog.books.length} kitap yazıldı\n`)
