import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

@MainActor
struct AnalysisDataTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeContext() throws -> ModelContext {
        ModelContext(try FokusStore.makeInMemoryContainer())
    }

    private func build(
        _ context: ModelContext, field: YksField = .say, extraBooks: [Book] = []
    ) throws -> AnalysisData {
        AnalysisData.build(
            subjects: try context.fetch(FetchDescriptor<Subject>()),
            topics: try context.fetch(FetchDescriptor<Topic>()),
            results: try context.fetch(FetchDescriptor<TestResult>()),
            books: try context.fetch(FetchDescriptor<Book>()) + extraBooks,
            field: field)
    }

    @Test func visibleSubjectsFilterByFieldAndKeepCustom() throws {
        let context = try makeContext()
        try CurriculumSeeder.ensureSeeded(context: context)
        let repo = AnalysisRepository(context: context)
        try repo.addSubject(name: "Benim Dersim", exam: .tyt, field: .dil, existingCount: 0, now: t0)
        let say = try build(context, field: .say)
        let dil = try build(context, field: .dil)
        #expect(say.subjects.contains { $0.name == "Benim Dersim" })
        #expect(say.subjects.allSatisfy { $0.catalogKey == nil || $0.fields.contains(.say) })
        #expect(dil.subjects.allSatisfy { $0.catalogKey == nil || $0.fields.contains(.dil) })
        #expect(say.subjects.count != dil.subjects.count)
        // Sınav sırası: TYT → AYT → YDT.
        let exams = say.subjects.map(\.exam)
        #expect(exams == exams.sorted { $0.rawValue == "TYT" ? $1.rawValue != "TYT" : ($0.rawValue == "AYT" && $1.rawValue == "YDT") })
    }

    @Test func summariesGroupBySubjectAndTopicAndIgnoreDeleted() throws {
        let context = try makeContext()
        let repo = AnalysisRepository(context: context)
        let subject = try repo.addSubject(name: "A", exam: .tyt, field: .say, existingCount: 0, now: t0)
        let topic = try repo.addTopic(subjectId: subject.id, name: "K", existingCount: 0, now: t0)
        func add(_ topicId: UUID?, _ correct: Int, _ wrong: Int, _ blank: Int, _ takenAt: Date) throws -> TestResult {
            try repo.addResult(
                TestResultForm.Input(
                    subjectId: subject.id, topicId: topicId, bookId: nil, sourceName: nil, label: nil,
                    correct: correct, wrong: wrong, blank: blank, date: takenAt), now: takenAt)
        }
        _ = try add(topic.id, 8, 4, 0, t0)
        let older = try add(nil, 20, 0, 0, t0.addingTimeInterval(-86_400 * 3))
        let removed = try add(topic.id, 5, 5, 5, t0)
        try repo.deleteResult(removed, now: t0)
        _ = older

        let data = try build(context)
        #expect(data.results.count == 2)
        #expect(data.subjectSummaries[subject.id]?.testCount == 2)
        #expect(data.topicSummaries[topic.id]?.testCount == 1)
        #expect(data.results(forSubject: subject.id).first?.takenAt == t0)
        #expect(data.results(forTopic: topic.id).count == 1)
        #expect(data.untopicedResults(forSubject: subject.id).count == 1)
        #expect(data.topicsBySubject[subject.id]?.map(\.id) == [topic.id])
    }

    @Test func resultsOfHiddenSubjectsAreDropped() throws {
        let context = try makeContext()
        try CurriculumSeeder.ensureSeeded(context: context)
        let hidden = try #require(
            try context.fetch(FetchDescriptor<Subject>()).first { $0.catalogKey != nil && !$0.fields.contains(.say) })
        let repo = AnalysisRepository(context: context)
        try repo.addResult(
            TestResultForm.Input(
                subjectId: hidden.id, topicId: nil, bookId: nil, sourceName: nil, label: nil,
                correct: 1, wrong: 0, blank: 0, date: t0), now: t0)
        context.insert(TestResult(subjectId: nil, correct: 1, wrong: 0, blank: 0))
        try context.save()
        let data = try build(context, field: .say)
        #expect(data.results.isEmpty)
        #expect(data.subjectSummaries.isEmpty)
    }

    @Test func topicsSortedByOrderThenName() throws {
        let context = try makeContext()
        let repo = AnalysisRepository(context: context)
        let subject = try repo.addSubject(name: "A", exam: .tyt, field: .say, existingCount: 0, now: t0)
        try repo.addTopic(subjectId: subject.id, name: "Çay", existingCount: 5, now: t0)
        try repo.addTopic(subjectId: subject.id, name: "Zeytin", existingCount: 0, now: t0)
        try repo.addTopic(subjectId: subject.id, name: "Ayva", existingCount: 5, now: t0)
        let names = try build(context).topicsBySubject[subject.id]?.map(\.name)
        #expect(names == ["Zeytin", "Ayva", "Çay"])
    }

    @Test func duplicateCopiesKeepOldest() throws {
        let context = try makeContext()
        let id = UUID()
        let subject = Subject(name: "Eski", exam: .tyt, fields: [.say])
        subject.id = id
        subject.createdAt = t0
        let copy = Subject(name: "Yeni", exam: .tyt, fields: [.say])
        copy.id = id
        copy.createdAt = t0.addingTimeInterval(10)
        context.insert(subject)
        context.insert(copy)
        let data = try build(context)
        #expect(data.subjects.map(\.name) == ["Eski"])
    }

    @Test func bookOptionsHideArchivedExceptCurrent() throws {
        let context = try makeContext()
        let active = Book(title: "Çalışma")
        let archived = Book(title: "Eski", archivedAt: t0)
        let other = Book(title: "Arşiv", archivedAt: t0)
        for book in [active, archived, other] { context.insert(book) }
        try context.save()
        let data = try build(context)
        #expect(data.bookOptions().map(\.title) == ["Çalışma"])
        #expect(data.bookOptions(including: archived.id).map(\.title) == ["Çalışma", "Eski"])
    }

    @Test func snapshotMapsFields() {
        let result = TestResult(subjectId: UUID(), topicId: UUID(), takenAt: t0, correct: 3, wrong: 2, blank: 1)
        let snapshot = result.snapshot
        #expect(snapshot.id == result.id && snapshot.correct == 3 && snapshot.takenAt == t0)
        #expect(snapshot.topicId == result.topicId && snapshot.deletedAt == nil)
    }
}
