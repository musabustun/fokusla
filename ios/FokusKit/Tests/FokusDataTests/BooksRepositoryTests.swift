import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

// Kitap yazma akışı — web `bookActions.test.ts` vakaları.

@MainActor
struct BooksRepositoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let context: ModelContext
    private let repository: BooksRepository

    init() throws {
        context = ModelContext(try FokusStore.makeInMemoryContainer())
        repository = BooksRepository(context: context)
    }

    private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

    private func liveBooks() throws -> [Book] { try EntityStore<Book>(context: context).all() }
    private func liveProgress() throws -> [BookProgress] { try EntityStore<BookProgress>(context: context).all() }

    // MARK: Oluşturma / düzenleme

    @Test func createTrimsAndStores() throws {
        let book = try repository.create(
            BookInput(title: "  TYT Matematik  ", publisher: "  Çap ", kind: .lecture, unit: .page, totalUnits: 320),
            now: t0)
        #expect(book.title == "TYT Matematik" && book.publisher == "Çap")
        #expect(book.kind == .lecture && book.unit == .page && book.totalUnits == 320)
        #expect(book.createdAt == t0 && book.updatedAt == t0 && book.archivedAt == nil)
        #expect(try liveBooks().count == 1)
    }

    @Test func blankPublisherBecomesNil() throws {
        let book = try repository.create(BookInput(title: "A", publisher: "   "))
        #expect(book.publisher == nil)
    }

    @Test func createDerivesExamFromSubject() throws {
        let subject = EntityStore<Subject>(context: context).insert(
            Subject(name: "Matematik", exam: .ayt, fields: [.say]))
        let withSubject = try repository.create(BookInput(title: "A", subjectId: subject.id))
        let without = try repository.create(BookInput(title: "B"))
        #expect(withSubject.exam == .ayt && withSubject.subjectId == subject.id)
        #expect(without.exam == nil && without.subjectId == nil)
    }

    @Test func unknownSubjectYieldsNoExam() throws {
        let book = try repository.create(BookInput(title: "A", subjectId: UUID()))
        #expect(book.exam == nil)
    }

    @Test func emptyTitleIsRejected() throws {
        #expect(throws: BookValidationError.emptyTitle) { try repository.create(BookInput(title: "   ")) }
        #expect(try liveBooks().isEmpty)
    }

    @Test(arguments: [0, -3])
    func nonPositiveTotalIsRejected(total: Int) throws {
        #expect(throws: BookValidationError.invalidTotal) {
            try repository.create(BookInput(title: "A", totalUnits: total))
        }
    }

    @Test func unknownTotalIsAllowed() throws {
        #expect(try repository.create(BookInput(title: "A", totalUnits: nil)).totalUnits == nil)
    }

    @Test func updateChangesFieldsAndTouches() throws {
        let book = try repository.create(BookInput(title: "A", totalUnits: 10), now: t0)
        try repository.update(
            book, with: BookInput(title: "B", publisher: "X", kind: .practiceExam, unit: .section, totalUnits: nil),
            now: at(5))
        #expect(book.title == "B" && book.publisher == "X" && book.kind == .practiceExam)
        #expect(book.unit == .section && book.totalUnits == nil)
        #expect(book.createdAt == t0 && book.updatedAt == at(5))
    }

    @Test func updateValidates() throws {
        let book = try repository.create(BookInput(title: "A"))
        #expect(throws: BookValidationError.emptyTitle) { try repository.update(book, with: BookInput(title: "")) }
        #expect(book.title == "A")
    }

    // MARK: Arşiv / silme

    @Test func archiveAndRestore() throws {
        let book = try repository.create(BookInput(title: "A"), now: t0)
        try repository.setArchived(book, true, now: at(1))
        #expect(book.archivedAt == at(1) && book.updatedAt == at(1))
        try repository.setArchived(book, false, now: at(2))
        #expect(book.archivedAt == nil && book.updatedAt == at(2))
    }

    @Test func deleteSoftDeletesBookAndItsProgressOnly() throws {
        let doomed = try repository.create(BookInput(title: "Silinecek"))
        let kept = try repository.create(BookInput(title: "Kalacak"))
        try repository.addProgress(bookId: doomed.id, reachedUnit: 5)
        try repository.addProgress(bookId: doomed.id, reachedUnit: 9)
        try repository.addProgress(bookId: kept.id, reachedUnit: 3)

        try repository.delete(doomed, now: at(10))

        #expect(try liveBooks().map(\.id) == [kept.id])
        #expect(try liveProgress().map(\.bookId) == [kept.id])
        #expect(doomed.deletedAt == at(10))
        // Kalıcı silme yok: tombstone'lar duruyor.
        #expect(try EntityStore<BookProgress>(context: context).all(includeDeleted: true).count == 3)
    }

    // MARK: İlerleme

    @Test func addProgressStoresNormalizedEntry() throws {
        let book = try repository.create(BookInput(title: "A"))
        let entry = try repository.addProgress(bookId: book.id, reachedUnit: 40, note: "  zordu ", now: at(3))
        #expect(entry.bookId == book.id && entry.reachedUnit == 40 && entry.note == "zordu")
        #expect(entry.recordedAt == at(3) && entry.createdAt == at(3) && entry.topicId == nil)
    }

    @Test func blankNoteBecomesNil() throws {
        let book = try repository.create(BookInput(title: "A"))
        #expect(try repository.addProgress(bookId: book.id, reachedUnit: 1, note: "  ").note == nil)
        #expect(try repository.addProgress(bookId: book.id, reachedUnit: 1).note == nil)
    }

    @Test func zeroIsValidAndNegativeIsRejected() throws {
        let book = try repository.create(BookInput(title: "A"))
        try repository.addProgress(bookId: book.id, reachedUnit: 0)
        #expect(throws: BookValidationError.invalidReachedUnit) {
            try repository.addProgress(bookId: book.id, reachedUnit: -1)
        }
        #expect(try liveProgress().count == 1)
    }

    @Test func progressMayExceedTotal() throws {
        let book = try repository.create(BookInput(title: "A", totalUnits: 100))
        #expect(try repository.addProgress(bookId: book.id, reachedUnit: 150).reachedUnit == 150)
    }

    @Test func deleteProgressRemovesOnlyThatEntry() throws {
        let book = try repository.create(BookInput(title: "A"))
        let first = try repository.addProgress(bookId: book.id, reachedUnit: 10, now: at(1))
        let second = try repository.addProgress(bookId: book.id, reachedUnit: 20, now: at(2))
        try repository.deleteProgress(first, now: at(3))
        #expect(try liveProgress().map(\.id) == [second.id])
        #expect(first.deletedAt == at(3))
    }

    @Test func snapshotsMirrorModels() throws {
        let book = try repository.create(
            BookInput(title: "A", publisher: "P", kind: .lecture, unit: .test, totalUnits: 12), now: t0)
        let entry = try repository.addProgress(bookId: book.id, reachedUnit: 4, note: "n", now: at(1))
        let bookSnapshot = book.snapshot
        #expect(bookSnapshot.id == book.id && bookSnapshot.title == "A" && bookSnapshot.publisher == "P")
        #expect(bookSnapshot.kind == .lecture && bookSnapshot.unit == .test && bookSnapshot.totalUnits == 12)
        #expect(bookSnapshot.createdAt == t0 && bookSnapshot.deletedAt == nil && bookSnapshot.archivedAt == nil)
        let entrySnapshot = entry.snapshot
        #expect(entrySnapshot.bookId == book.id && entrySnapshot.reachedUnit == 4 && entrySnapshot.note == "n")
        #expect(entrySnapshot.recordedAt == at(1) && entrySnapshot.createdAt == at(1))
    }

    // MARK: Barkod ve bölümler

    @Test func createStoresBarcodeAndLibraryKey() throws {
        let book = try repository.create(
            BookInput(title: "A", barcode: "9786050000001", libraryKey: "lib-a"), now: t0)
        #expect(book.barcode == "9786050000001" && book.libraryKey == "lib-a")
        let updated = try repository.update(book, with: BookInput(title: "A"), now: at(1))
        #expect(updated.barcode == nil && updated.libraryKey == nil)
    }

    @Test func bookWithBarcodeReturnsOldestActiveMatch() throws {
        let newer = try repository.create(BookInput(title: "Yeni", barcode: "111"), now: at(5))
        let older = try repository.create(BookInput(title: "Eski", barcode: "111"), now: at(1))
        _ = try repository.create(BookInput(title: "Başka", barcode: "222"), now: at(0))
        #expect(try repository.book(withBarcode: "111")?.id == older.id)
        try repository.delete(older, now: at(6))
        #expect(try repository.book(withBarcode: "111")?.id == newer.id)
        #expect(try repository.book(withBarcode: "yok") == nil)
    }

    @Test func sectionsAreOrderedAndReplaced() throws {
        let book = try repository.create(BookInput(title: "A"), now: t0)
        try repository.replaceSections(
            [
                BookSectionInput(title: "İkinci", order: 2, startUnit: 10, endUnit: 20),
                BookSectionInput(title: "  Birinci ", order: 1),
            ], for: book, now: at(1))
        #expect(try repository.sections(of: book.id).map(\.title) == ["Birinci", "İkinci"])

        try repository.replaceSections([BookSectionInput(title: "Yeni", order: 0)], for: book, now: at(2))
        #expect(try repository.sections(of: book.id).map(\.title) == ["Yeni"])
        let all = try context.fetch(FetchDescriptor<BookSection>())
        #expect(all.count == 3 && all.filter { $0.deletedAt != nil }.count == 2)
    }

    @Test func deletingBookSoftDeletesItsSections() throws {
        let book = try repository.create(BookInput(title: "A"), now: t0)
        let other = try repository.create(BookInput(title: "B"), now: t0)
        try repository.replaceSections([BookSectionInput(title: "x", order: 0)], for: book, now: t0)
        try repository.replaceSections([BookSectionInput(title: "y", order: 0)], for: other, now: t0)
        try repository.delete(book, now: at(1))
        #expect(try repository.sections(of: book.id).isEmpty)
        #expect(try repository.sections(of: other.id).count == 1)
    }
}
