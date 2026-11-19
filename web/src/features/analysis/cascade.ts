/** Kullanıcı ders/konu silmelerinin bağlı kayıtlara etkisi (repository üzerinden, soft delete). */
import type { Repositories } from '@/data'
import type { UUID } from '@/domain'

/** Dersi, konularını ve test sonuçlarını soft-delete eder. */
export async function deleteSubjectCascade(repositories: Repositories, id: UUID): Promise<void> {
  const [topics, results] = await Promise.all([
    repositories.topics.findBySubject(id),
    repositories.testResults.findBySubject(id),
  ])
  await Promise.all(results.map((result) => repositories.testResults.delete(result.id)))
  await Promise.all(topics.map((topic) => repositories.topics.delete(topic.id)))
  await repositories.subjects.delete(id)
}

/** Konuyu soft-delete eder; test sonuçlarının topicId'sini null yapar. */
export async function deleteTopicKeepingResults(
  repositories: Repositories,
  id: UUID,
): Promise<void> {
  const results = await repositories.testResults.findByTopic(id)
  await Promise.all(
    results.map((result) => repositories.testResults.update(result.id, { topicId: null })),
  )
  await repositories.topics.delete(id)
}
