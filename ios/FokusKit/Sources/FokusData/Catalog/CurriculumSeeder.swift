import FokusDomain
import Foundation
import SwiftData

// Müfredat kataloğunu `Subject`/`Topic` olarak tohumlar. Web `ensureCurriculumSeeded` ile aynı
// davranış: idempotent, `catalogKey` ile eşleştirme, id = UUID v5 (`catalogEntityId`).
// Web semantiği: eşleştirme yalnızca SİLİNMEMİŞ kayıtlara bakar (`findByCatalogKey` /
// `findBySubject` tombstone'ları hariç tutar); soft-delete edilmiş katalog kaydı "eksik" sayılır
// ve yeniden oluşturulur.

/// Tohumlama sonucu (web `SeedResult`).
public struct SeedResult: Sendable, Equatable {
    public var subjectsCreated: Int
    public var topicsCreated: Int

    public init(subjectsCreated: Int, topicsCreated: Int) {
        self.subjectsCreated = subjectsCreated
        self.topicsCreated = topicsCreated
    }
}

@MainActor
public enum CurriculumSeeder {
    /// Paketle gelen müfredat kataloğunu idempotent biçimde tohumlar. Uygulama açılışında çağrılır.
    @discardableResult
    public static func ensureSeeded(context: ModelContext) throws -> SeedResult {
        try ensureSeeded(context: context, catalog: CurriculumCatalog.bundled(), now: .now)
    }

    /// Verilen kataloğu tohumlar; yalnızca eksik kayıtları oluşturur ve sonunda bir kez kaydeder.
    @discardableResult
    public static func ensureSeeded(
        context: ModelContext,
        catalog: CurriculumCatalog,
        now: Date
    ) throws -> SeedResult {
        let subjectStore = EntityStore<Subject>(context: context)
        let topicStore = EntityStore<Topic>(context: context)

        var subjectsByKey: [String: Subject] = [:]
        for subject in try subjectStore.all() {
            if let key = subject.catalogKey, subjectsByKey[key] == nil { subjectsByKey[key] = subject }
        }
        var existingTopicKeys: [UUID: Set<String>] = [:]
        for topic in try topicStore.all() {
            guard let subjectId = topic.subjectId, let key = topic.catalogKey else { continue }
            existingTopicKeys[subjectId, default: []].insert(key)
        }

        var result = SeedResult(subjectsCreated: 0, topicsCreated: 0)
        for (subjectOrder, catalogSubject) in catalog.subjects.enumerated() {
            let subject: Subject
            if let existing = subjectsByKey[catalogSubject.key] {
                subject = existing
            } else {
                subject = subjectStore.insert(
                    Subject(
                        id: Identifiers.catalogEntityId(catalogSubject.key),
                        name: catalogSubject.name,
                        exam: catalogSubject.exam,
                        fields: catalogSubject.fields,
                        catalogKey: catalogSubject.key,
                        order: subjectOrder
                    ),
                    now: now
                )
                result.subjectsCreated += 1
            }

            let known = existingTopicKeys[subject.id] ?? []
            for (topicOrder, catalogTopic) in catalogSubject.topics.enumerated()
            where !known.contains(catalogTopic.key) {
                topicStore.insert(
                    Topic(
                        id: Identifiers.catalogEntityId(catalogTopic.key),
                        subjectId: subject.id,
                        name: catalogTopic.name,
                        catalogKey: catalogTopic.key,
                        order: topicOrder
                    ),
                    now: now
                )
                result.topicsCreated += 1
            }
        }
        try subjectStore.save()
        return result
    }
}
