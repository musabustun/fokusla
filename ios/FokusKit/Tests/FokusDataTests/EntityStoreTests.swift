import Foundation
import SwiftData
import Testing

@testable import FokusData

@MainActor
struct EntityStoreTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeStore() throws -> EntityStore<Topic> {
        EntityStore(context: ModelContext(try FokusStore.makeInMemoryContainer()))
    }

    @Test func insertFillsTimestamps() throws {
        let store = try makeStore()
        let topic = store.insert(Topic(subjectId: nil, name: "A"), now: t0)
        #expect(topic.createdAt == t0 && topic.updatedAt == t0 && topic.deletedAt == nil)
        try store.save()
        #expect(try store.all().count == 1)
        #expect(try store.find(id: topic.id)?.name == "A")
    }

    @Test func touchAdvancesUpdatedAt() throws {
        let store = try makeStore()
        let topic = store.insert(Topic(subjectId: nil, name: "A"), now: t0)
        store.touch(topic, now: t0.addingTimeInterval(5))
        #expect(topic.updatedAt == t0.addingTimeInterval(5) && topic.createdAt == t0)
    }

    @Test func softDeleteHidesFromAll() throws {
        let store = try makeStore()
        let topic = store.insert(Topic(subjectId: nil, name: "A"), now: t0)
        store.softDelete(topic, now: t0.addingTimeInterval(1))
        try store.save()
        #expect(try store.all().isEmpty)
        #expect(try store.find(id: topic.id) == nil)
        #expect(try store.all(includeDeleted: true).count == 1)
        #expect(try store.find(id: topic.id, includeDeleted: true) != nil)
    }

    @Test func duplicateIdsKeepOldestCreatedAt() throws {
        let store = try makeStore()
        let id = UUID()
        store.insert(Topic(id: id, subjectId: nil, name: "newer"), now: t0.addingTimeInterval(10))
        store.insert(Topic(id: id, subjectId: nil, name: "oldest"), now: t0)
        store.insert(Topic(id: id, subjectId: nil, name: "middle"), now: t0.addingTimeInterval(5))
        try store.save()
        let all = try store.all()
        #expect(all.count == 1)
        #expect(all.first?.name == "oldest")
    }
}
