import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

@MainActor
struct AnalysisRepositoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }

    private func make() throws -> (AnalysisRepository, ModelContext) {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        return (AnalysisRepository(context: context), context)
    }

    private func input(
        subject: UUID, topic: UUID? = nil, book: UUID? = nil, source: String? = nil, label: String? = nil,
        correct: Int = 10, wrong: Int = 4, blank: Int = 6, date: Date
    ) -> TestResultForm.Input {
        TestResultForm.Input(
            subjectId: subject, topicId: topic, bookId: book, sourceName: source, label: label,
            correct: correct, wrong: wrong, blank: blank, date: date)
    }

    // MARK: Sonuçlar

    @Test func addResultStoresFieldsAndTodayKeepsNow() throws {
        let (repo, context) = try make()
        let subject = UUID()
        let result = try repo.addResult(
            input(subject: subject, label: "Test 12", date: t0), now: t0, calendar: calendar)
        #expect(result.subjectId == subject && result.label == "Test 12")
        #expect(result.takenAt == t0 && result.createdAt == t0)
        #expect(result.correct == 10 && result.wrong == 4 && result.blank == 6)
        #expect(try EntityStore<TestResult>(context: context).all().count == 1)
    }

    @Test func addResultForPastDayUsesLocalNoon() throws {
        let (repo, _) = try make()
        let yesterday = calendar.date(byAdding: .day, value: -3, to: t0)!
        let result = try repo.addResult(input(subject: UUID(), date: yesterday), now: t0, calendar: calendar)
        let parts = calendar.dateComponents([.hour, .minute], from: result.takenAt)
        #expect(parts.hour == 12 && parts.minute == 0)
        #expect(Identifiers.isoDate(result.takenAt, calendar: calendar) == Identifiers.isoDate(yesterday, calendar: calendar))
    }

    @Test func updateResultKeepsTakenAtWhenDayUnchanged() throws {
        let (repo, _) = try make()
        let subject = UUID()
        let result = try repo.addResult(input(subject: subject, date: t0), now: t0, calendar: calendar)
        let later = t0.addingTimeInterval(3600)
        try repo.updateResult(
            result, with: input(subject: subject, source: "Fasikül", correct: 20, wrong: 0, blank: 0, date: t0),
            now: later, calendar: calendar)
        #expect(result.takenAt == t0)
        #expect(result.updatedAt == later)
        #expect(result.correct == 20 && result.sourceName == "Fasikül")
    }

    @Test func updateResultMovesTakenAtWhenDayChanges() throws {
        let (repo, _) = try make()
        let subject = UUID()
        let result = try repo.addResult(input(subject: subject, date: t0), now: t0, calendar: calendar)
        let earlier = calendar.date(byAdding: .day, value: -2, to: t0)!
        try repo.updateResult(result, with: input(subject: subject, date: earlier), now: t0, calendar: calendar)
        #expect(Identifiers.isoDate(result.takenAt, calendar: calendar) == Identifiers.isoDate(earlier, calendar: calendar))
    }

    @Test func deleteResultIsSoft() throws {
        let (repo, context) = try make()
        let result = try repo.addResult(input(subject: UUID(), date: t0), now: t0, calendar: calendar)
        try repo.deleteResult(result, now: t0.addingTimeInterval(5))
        #expect(result.deletedAt == t0.addingTimeInterval(5))
        #expect(try EntityStore<TestResult>(context: context).all().isEmpty)
        #expect(try EntityStore<TestResult>(context: context).all(includeDeleted: true).count == 1)
    }

    // MARK: Dersler

    @Test func addSubjectUsesCustomOrderAndField() throws {
        let (repo, _) = try make()
        let subject = try repo.addSubject(name: "Problemler", exam: .ayt, field: .ea, existingCount: 2, now: t0)
        #expect(subject.catalogKey == nil && subject.order == 1002)
        #expect(subject.exam == .ayt && subject.fields == [.ea])
    }

    @Test func updateSubjectRenames() throws {
        let (repo, _) = try make()
        let subject = try repo.addSubject(name: "A", exam: .tyt, field: .say, existingCount: 0, now: t0)
        try repo.updateSubject(subject, name: "B", exam: .ydt, now: t0.addingTimeInterval(1))
        #expect(subject.name == "B" && subject.exam == .ydt && subject.updatedAt == t0.addingTimeInterval(1))
    }

    @Test func catalogSubjectsAndTopicsAreReadOnly() throws {
        let (repo, context) = try make()
        try CurriculumSeeder.ensureSeeded(context: context)
        let subject = try #require(EntityStore<Subject>(context: context).all().first { $0.catalogKey != nil })
        let topic = try #require(EntityStore<Topic>(context: context).all().first { $0.catalogKey != nil })
        #expect(subject.isCatalogEntry && topic.isCatalogEntry)
        #expect(throws: AnalysisRepository.RepositoryError.catalogEntityReadOnly) {
            try repo.updateSubject(subject, name: "x", exam: .tyt)
        }
        #expect(throws: AnalysisRepository.RepositoryError.catalogEntityReadOnly) {
            try repo.deleteSubject(subject)
        }
        #expect(throws: AnalysisRepository.RepositoryError.catalogEntityReadOnly) {
            try repo.updateTopic(topic, name: "x")
        }
        #expect(throws: AnalysisRepository.RepositoryError.catalogEntityReadOnly) {
            try repo.deleteTopic(topic)
        }
    }

    @Test func deleteSubjectCascadesToTopicsAndResults() throws {
        let (repo, context) = try make()
        let subject = try repo.addSubject(name: "A", exam: .tyt, field: .say, existingCount: 0, now: t0)
        let other = try repo.addSubject(name: "B", exam: .tyt, field: .say, existingCount: 1, now: t0)
        let topic = try repo.addTopic(subjectId: subject.id, name: "K", existingCount: 0, now: t0)
        let otherTopic = try repo.addTopic(subjectId: other.id, name: "L", existingCount: 0, now: t0)
        try repo.addResult(input(subject: subject.id, topic: topic.id, date: t0), now: t0, calendar: calendar)
        try repo.addResult(input(subject: other.id, topic: otherTopic.id, date: t0), now: t0, calendar: calendar)

        try repo.deleteSubject(subject, now: t0.addingTimeInterval(1))

        #expect(try EntityStore<Subject>(context: context).all().map(\.id) == [other.id])
        #expect(try EntityStore<Topic>(context: context).all().map(\.id) == [otherTopic.id])
        #expect(try EntityStore<TestResult>(context: context).all().map(\.subjectId) == [other.id])
    }

    // MARK: Konular

    @Test func topicLifecycleKeepsResultsWithoutTopic() throws {
        let (repo, context) = try make()
        let subject = try repo.addSubject(name: "A", exam: .tyt, field: .say, existingCount: 0, now: t0)
        let topic = try repo.addTopic(subjectId: subject.id, name: "Eski", existingCount: 3, now: t0)
        #expect(topic.order == 1003 && topic.catalogKey == nil)
        try repo.updateTopic(topic, name: "Yeni", now: t0.addingTimeInterval(1))
        #expect(topic.name == "Yeni")

        let result = try repo.addResult(
            input(subject: subject.id, topic: topic.id, date: t0), now: t0, calendar: calendar)
        try repo.deleteTopic(topic, now: t0.addingTimeInterval(2))

        #expect(result.topicId == nil && result.deletedAt == nil)
        #expect(result.updatedAt == t0.addingTimeInterval(2))
        #expect(try EntityStore<Topic>(context: context).all().isEmpty)
        #expect(try EntityStore<TestResult>(context: context).all().count == 1)
    }
}
