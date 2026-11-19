/**
 * Müfredat kataloğunu Subject/Topic kayıtları olarak tohumlar.
 * Idempotent: kayıtlar `catalogKey` ile eşleştirilir; mevcut olanlar atlanır, yalnızca eksikler
 * eklenir (ikinci çalıştırma 0 kayıt oluşturur). `order` katalogdaki sırayı korur.
 * Kayıt id'leri catalogKey'den deterministik türetilir (UUID v5, `catalogEntityId`): her cihaz aynı
 * id'yi üretir, böylece CloudKit senkronunda katalog kayıtları kopyalanmaz, birleşir.
 */
import type { CatalogSubject, Curriculum } from '@/curriculum'
import { catalogEntityId, type Subject } from '@/domain'
import type { Repositories } from '../repository'

export interface SeedResult {
  subjectsCreated: number
  topicsCreated: number
}

/** Aynı repository kümesi için eşzamanlı çağrıları (ör. StrictMode çift efekt) tek işe indirger. */
const inFlight = new WeakMap<Repositories, Promise<SeedResult>>()

export function ensureCurriculumSeeded(
  repositories: Repositories,
  curriculum: Curriculum,
): Promise<SeedResult> {
  const running = inFlight.get(repositories)
  if (running) return running
  const task = seed(repositories, curriculum).finally(() => inFlight.delete(repositories))
  inFlight.set(repositories, task)
  return task
}

async function seed(repositories: Repositories, curriculum: Curriculum): Promise<SeedResult> {
  let subjectsCreated = 0
  let topicsCreated = 0
  for (const [order, catalogSubject] of curriculum.subjects.entries()) {
    const { subject, created } = await ensureSubject(repositories, catalogSubject, order)
    if (created) subjectsCreated += 1
    topicsCreated += await ensureTopics(repositories, catalogSubject, subject)
  }
  return { subjectsCreated, topicsCreated }
}

async function ensureSubject(
  repositories: Repositories,
  catalogSubject: CatalogSubject,
  order: number,
): Promise<{ subject: Subject; created: boolean }> {
  const existing = await repositories.subjects.findByCatalogKey(catalogSubject.key)
  if (existing) return { subject: existing, created: false }
  const subject = await repositories.subjects.create(
    {
      name: catalogSubject.name,
      exam: catalogSubject.exam,
      fields: [...catalogSubject.fields],
      catalogKey: catalogSubject.key,
      order,
    },
    { id: await catalogEntityId(catalogSubject.key) },
  )
  return { subject, created: true }
}

async function ensureTopics(
  repositories: Repositories,
  catalogSubject: CatalogSubject,
  subject: Subject,
): Promise<number> {
  const existing = await repositories.topics.findBySubject(subject.id)
  const existingKeys = new Set(existing.map((topic) => topic.catalogKey))
  const missing = [...catalogSubject.topics.entries()].filter(
    ([, topic]) => !existingKeys.has(topic.key),
  )
  for (const [order, topic] of missing) {
    await repositories.topics.create(
      { subjectId: subject.id, name: topic.name, catalogKey: topic.key, order },
      { id: await catalogEntityId(topic.key) },
    )
  }
  return missing.length
}
