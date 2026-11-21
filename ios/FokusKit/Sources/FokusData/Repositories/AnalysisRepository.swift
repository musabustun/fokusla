import FokusDomain
import Foundation
import SwiftData

/// Analiz modülünün yazma işlemleri: test sonuçları ile kullanıcı tanımlı ders/konular.
/// Sahibi: analysis modülü. Okuma için ekranlar `@Query` + `AnalysisData` kullanır.
///
/// Katalog (`catalogKey != nil`) ders/konuları düzenlenemez/silinemez (`CurriculumSeeder` yazar).
@MainActor
public struct AnalysisRepository {
    /// Kullanıcı tanımlı ders/konuların sıralama tabanı: katalog kayıtlarından sonra gelir.
    public static let customOrderBase = 1000

    public enum RepositoryError: Error, Equatable, Sendable {
        /// Müfredat dersi/konusu değiştirilemez.
        case catalogEntityReadOnly
    }

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    private var results: EntityStore<TestResult> { EntityStore(context: context) }
    private var subjects: EntityStore<Subject> { EntityStore(context: context) }
    private var topics: EntityStore<Topic> { EntityStore(context: context) }

    // MARK: - Test sonuçları

    /// Yeni test sonucu ekler. `takenAt`: bugünse şu an, değilse seçilen günün yerel öğlesi.
    @discardableResult
    public func addResult(
        _ input: TestResultForm.Input, now: Date = .now, calendar: Calendar = .current
    ) throws -> TestResult {
        let result = TestResult(
            subjectId: input.subjectId, topicId: input.topicId, bookId: input.bookId,
            label: input.label, sourceName: input.sourceName,
            takenAt: TestResultForm.takenAt(for: input.date, now: now, calendar: calendar),
            correct: input.correct, wrong: input.wrong, blank: input.blank)
        results.insert(result, now: now)
        try results.save()
        return result
    }

    /// Mevcut sonucu günceller; gün değişmediyse `takenAt` korunur.
    public func updateResult(
        _ result: TestResult, with input: TestResultForm.Input, now: Date = .now,
        calendar: Calendar = .current
    ) throws {
        result.subjectId = input.subjectId
        result.topicId = input.topicId
        result.bookId = input.bookId
        result.sourceName = input.sourceName
        result.label = input.label
        result.correct = input.correct
        result.wrong = input.wrong
        result.blank = input.blank
        result.takenAt = TestResultForm.takenAt(
            for: input.date, existing: result.takenAt, now: now, calendar: calendar)
        results.touch(result, now: now)
        try results.save()
    }

    /// Test sonucunu siler (tombstone).
    public func deleteResult(_ result: TestResult, now: Date = .now) throws {
        results.softDelete(result, now: now)
        try results.save()
    }

    // MARK: - Dersler

    /// Kullanıcı dersi ekler (`fields: [field]`, sıra: `customOrderBase + existingCount`).
    @discardableResult
    public func addSubject(
        name: String, exam: ExamType, field: YksField, existingCount: Int, now: Date = .now
    ) throws -> Subject {
        let subject = Subject(
            name: name, exam: exam, fields: [field], catalogKey: nil,
            order: Self.customOrderBase + existingCount)
        subjects.insert(subject, now: now)
        try subjects.save()
        return subject
    }

    /// Kullanıcı dersini yeniden adlandırır / sınavını değiştirir.
    public func updateSubject(
        _ subject: Subject, name: String, exam: ExamType, now: Date = .now
    ) throws {
        guard subject.catalogKey == nil else { throw RepositoryError.catalogEntityReadOnly }
        subject.name = name
        subject.exam = exam
        subjects.touch(subject, now: now)
        try subjects.save()
    }

    /// Kullanıcı dersini, konularını ve test sonuçlarını siler (tombstone).
    public func deleteSubject(_ subject: Subject, now: Date = .now) throws {
        guard subject.catalogKey == nil else { throw RepositoryError.catalogEntityReadOnly }
        for result in try results.all() where result.subjectId == subject.id {
            results.softDelete(result, now: now)
        }
        for topic in try topics.all() where topic.subjectId == subject.id {
            topics.softDelete(topic, now: now)
        }
        subjects.softDelete(subject, now: now)
        try subjects.save()
    }

    // MARK: - Konular

    /// Kullanıcı konusu ekler (sıra: `customOrderBase + existingCount`).
    @discardableResult
    public func addTopic(
        subjectId: UUID, name: String, existingCount: Int, now: Date = .now
    ) throws -> Topic {
        let topic = Topic(
            subjectId: subjectId, name: name, catalogKey: nil, order: Self.customOrderBase + existingCount)
        topics.insert(topic, now: now)
        try topics.save()
        return topic
    }

    /// Kullanıcı konusunu yeniden adlandırır.
    public func updateTopic(_ topic: Topic, name: String, now: Date = .now) throws {
        guard topic.catalogKey == nil else { throw RepositoryError.catalogEntityReadOnly }
        topic.name = name
        topics.touch(topic, now: now)
        try topics.save()
    }

    /// Konuyu siler (tombstone); test sonuçlarının `topicId`'si `nil` olur ("Konu seçilmedi").
    public func deleteTopic(_ topic: Topic, now: Date = .now) throws {
        guard topic.catalogKey == nil else { throw RepositoryError.catalogEntityReadOnly }
        for result in try results.all() where result.topicId == topic.id {
            result.topicId = nil
            results.touch(result, now: now)
        }
        topics.softDelete(topic, now: now)
        try topics.save()
    }
}

extension Subject {
    /// Müfredat kataloğundan gelen ders mi? (düzenlenemez)
    public var isCatalogEntry: Bool { catalogKey != nil }
}

extension Topic {
    /// Müfredat kataloğundan gelen konu mu? (düzenlenemez)
    public var isCatalogEntry: Bool { catalogKey != nil }
}
