import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

@MainActor
struct CurriculumSeederTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func totals(_ catalog: CurriculumCatalog) -> SeedResult {
        SeedResult(
            subjectsCreated: catalog.subjects.count,
            topicsCreated: catalog.subjects.reduce(0) { $0 + $1.topics.count }
        )
    }

    @Test func firstRunCreatesEverythingSecondRunNothing() throws {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        let catalog = try CurriculumCatalog.bundled()
        let first = try CurriculumSeeder.ensureSeeded(context: context, catalog: catalog, now: now)
        #expect(first == totals(catalog))
        let second = try CurriculumSeeder.ensureSeeded(context: context, catalog: catalog, now: now)
        #expect(second == SeedResult(subjectsCreated: 0, topicsCreated: 0))
        #expect(try EntityStore<Subject>(context: context).all().count == catalog.subjects.count)
    }

    @Test func bundledOverloadSeeds() throws {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        let result = try CurriculumSeeder.ensureSeeded(context: context)
        #expect(result == totals(try CurriculumCatalog.bundled()))
    }

    @Test func idsOrderAndFieldsAreCorrect() throws {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        let catalog = try CurriculumCatalog.bundled()
        try CurriculumSeeder.ensureSeeded(context: context, catalog: catalog, now: now)

        let subjects = try EntityStore<Subject>(context: context).all()
        let topics = try EntityStore<Topic>(context: context).all()
        let index = try #require(catalog.subjects.indices.last)
        let catalogSubject = catalog.subjects[index]
        let subject = try #require(subjects.first { $0.catalogKey == catalogSubject.key })
        #expect(subject.id == Identifiers.catalogEntityId(catalogSubject.key))
        #expect(subject.order == index)
        #expect(subject.name == catalogSubject.name)
        #expect(subject.exam == catalogSubject.exam)
        #expect(subject.fields == catalogSubject.fields)
        #expect(subject.createdAt == now && subject.updatedAt == now && subject.deletedAt == nil)

        let ownTopics = topics.filter { $0.subjectId == subject.id }.sorted { $0.order < $1.order }
        #expect(ownTopics.map(\.catalogKey) == catalogSubject.topics.map(\.key))
        #expect(ownTopics.map(\.order) == Array(catalogSubject.topics.indices))
        #expect(ownTopics.first?.id == Identifiers.catalogEntityId(catalogSubject.topics[0].key))
        #expect(ownTopics.first?.createdAt == now)
    }

    @Test func partialExistingDataOnlyMissingCreated() throws {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        let catalog = try CurriculumCatalog.bundled()
        let first = try #require(catalog.subjects.first)
        let store = EntityStore<Subject>(context: context)
        store.insert(
            Subject(
                id: Identifiers.catalogEntityId(first.key), name: first.name, exam: first.exam,
                fields: first.fields, catalogKey: first.key, order: 0
            ),
            now: now
        )
        try store.save()
        let result = try CurriculumSeeder.ensureSeeded(context: context, catalog: catalog, now: now)
        #expect(result.subjectsCreated == catalog.subjects.count - 1)
        #expect(result.topicsCreated == totals(catalog).topicsCreated)
        #expect(try store.all().count == catalog.subjects.count)
    }

    // Web semantiği: tombstone'lar eşleştirmede yok sayılır, kayıt yeniden oluşturulur.
    @Test func softDeletedCatalogSubjectIsRecreated() throws {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        let catalog = try CurriculumCatalog.bundled()
        try CurriculumSeeder.ensureSeeded(context: context, catalog: catalog, now: now)
        let store = EntityStore<Subject>(context: context)
        let victim = try #require(store.all().first)
        store.softDelete(victim, now: now)
        try store.save()

        let later = now.addingTimeInterval(60)
        let result = try CurriculumSeeder.ensureSeeded(context: context, catalog: catalog, now: later)
        #expect(result.subjectsCreated == 1)
        #expect(result.topicsCreated == 0)
        #expect(try store.all().count == catalog.subjects.count)
    }

    @Test func subjectsForFieldKeepsCatalogOrder() throws {
        let catalog = try CurriculumCatalog.bundled()
        for field in YksField.allCases {
            let subjects = catalog.subjects(for: field)
            #expect(!subjects.isEmpty)
            #expect(subjects.allSatisfy { $0.fields.contains(field) })
            let order = subjects.compactMap { s in catalog.subjects.firstIndex(of: s) }
            #expect(order == order.sorted())
        }
    }
}
