/**
 * Web müfredat kataloğunu iOS'a aktarır (`npm run export:ios-curriculum`):
 *  - ios/FokusKit/Sources/FokusData/Resources/yks-curriculum.json
 *  - ios/FokusKit/Tests/FokusDataTests/Fixtures/catalog-ids.web.json
 *    (her ders/konu anahtarı → web `catalogEntityId` ile hesaplanan küçük harfli UUID v5;
 *    Swift testi aynı id'leri üretmeyi doğrular — web algoritması doğruluk kaynağıdır).
 * Vite modül çalıştırıcısı üzerinden çalışır; `@/` takma adı vite.config.ts'ten gelir.
 */
import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { runnerImport } from 'vite'
import type { Curriculum } from '../src/curriculum/types'

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const iosKit = resolve(webRoot, '../ios/FokusKit')
const curriculumOut = resolve(iosKit, 'Sources/FokusData/Resources/yks-curriculum.json')
const idsOut = resolve(iosKit, 'Tests/FokusDataTests/Fixtures/catalog-ids.web.json')

async function load<T>(path: string): Promise<T> {
  const { module } = await runnerImport<T>(resolve(webRoot, path), { root: webRoot })
  return module
}

const { yksCurriculum } = await load<{ yksCurriculum: Curriculum }>('src/curriculum/yks.ts')
const { toIosCurriculumJson } = await load<{
  toIosCurriculumJson: (curriculum: Curriculum) => Curriculum
}>('src/curriculum/iosExport.ts')
const { catalogEntityId } = await load<{ catalogEntityId: (key: string) => Promise<string> }>(
  'src/domain/ids.ts',
)

const catalog = toIosCurriculumJson(yksCurriculum)
const ids: Record<string, string> = {}
for (const subject of catalog.subjects) {
  ids[subject.key] = await catalogEntityId(subject.key)
  for (const topic of subject.topics) ids[topic.key] = await catalogEntityId(topic.key)
}

function write(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`)
}
write(curriculumOut, catalog)
write(idsOut, ids)
process.stdout.write(`${Object.keys(ids).length} katalog anahtarı yazıldı\n`)
