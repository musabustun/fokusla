/**
 * Web renk paletlerini iOS'a aktarır (`npm run export:ios-palettes`):
 *  - ios/FokusKit/Tests/FokusDesignTests/Fixtures/palettes.web.json
 * Ardından `python3 ios/scripts/generate_palette_assets.py` bu dosyadan Asset Catalog'u
 * (Colors.xcassets/<Palet>/<Token>, Any = açık, Dark = koyu) üretir; Swift testi her rengi bu
 * dosyayla karşılaştırır. Kaynak `web/src/ui/tokens.ts` (`PALETTES`, `PALETTE_LABELS`).
 */
import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { runnerImport } from 'vite'
import type * as Tokens from '../src/ui/tokens'

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const out = resolve(webRoot, '../ios/FokusKit/Tests/FokusDesignTests/Fixtures/palettes.web.json')

const { module: tokens } = await runnerImport<typeof Tokens>(resolve(webRoot, 'src/ui/tokens.ts'), {
  root: webRoot,
})
const { toIosPalettesJson } = (
  await runnerImport<typeof import('../src/ui/iosPalettes')>(
    resolve(webRoot, 'src/ui/iosPalettes.ts'),
    { root: webRoot },
  )
).module

mkdirSync(dirname(out), { recursive: true })
writeFileSync(out, `${JSON.stringify(toIosPalettesJson(tokens), null, 2)}\n`)
process.stdout.write(`${tokens.PALETTE_NAMES.length} palet yazıldı\n`)
