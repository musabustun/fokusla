import FokusDomain
import Foundation
import SwiftData

/// Kitap formunun doğrulanmış değerleri (web `BookInput`).
public struct BookInput: Sendable, Equatable {
    public var title: String
    public var publisher: String?
    public var kind: BookKind
    public var subjectId: UUID?
    public var unit: BookUnit
    /// Toplam birim; bilinmiyorsa `nil`. Pozitif olmalı.
    public var totalUnits: Int?

    public init(
        title: String, publisher: String? = nil, kind: BookKind = .questionBank,
        subjectId: UUID? = nil, unit: BookUnit = .test, totalUnits: Int? = nil
    ) {
        self.title = title
        self.publisher = publisher
        self.kind = kind
        self.subjectId = subjectId
        self.unit = unit
        self.totalUnits = totalUnits
    }
}

/// Kitap işlemlerinin kullanıcıya gösterilebilir doğrulama hatası (web `BookValidationError`).
public struct BookValidationError: Error, Equatable, LocalizedError {
    public let message: String
    public var errorDescription: String? { message }

    public init(_ message: String) { self.message = message }

    public static let emptyTitle = BookValidationError("Kitap adı boş olamaz.")
    public static let invalidTotal = BookValidationError("Toplam pozitif bir tam sayı olmalı.")
    public static let invalidReachedUnit = BookValidationError("Geçerli bir sayı gir.")
}

/// Kitap modülünün yazma işlemleri (web `features/books/bookActions.ts` karşılığı). Sahibi: books modülü.
///
/// Doğrulama ve "kitap silinince ilerleme kayıtları da silinir" kuralı burada tek yerde durur;
/// ekranlar `EntityStore`'a doğrudan yazmaz. Silme yalnızca `deletedAt` set eder (tombstone).
@MainActor
public struct BooksRepository {
    private let books: EntityStore<Book>
    private let progress: EntityStore<BookProgress>
    private let subjects: EntityStore<Subject>

    public init(context: ModelContext) {
        books = EntityStore(context: context)
        progress = EntityStore(context: context)
        subjects = EntityStore(context: context)
    }

    // MARK: - Kitap

    /// Yeni kitap ekler. `exam`, seçilen dersin sınavından türetilir (ders yoksa `nil`).
    @discardableResult
    public func create(_ input: BookInput, now: Date = .now) throws -> Book {
        let clean = try Self.normalized(input)
        let book = books.insert(
            Book(
                title: clean.title, publisher: clean.publisher, kind: clean.kind,
                subjectId: clean.subjectId, exam: try exam(of: clean.subjectId),
                unit: clean.unit, totalUnits: clean.totalUnits),
            now: now)
        try books.save()
        return book
    }

    /// Kitabın alanlarını günceller (arşiv durumu değişmez).
    @discardableResult
    public func update(_ book: Book, with input: BookInput, now: Date = .now) throws -> Book {
        let clean = try Self.normalized(input)
        book.title = clean.title
        book.publisher = clean.publisher
        book.kind = clean.kind
        book.subjectId = clean.subjectId
        book.exam = try exam(of: clean.subjectId)
        book.unit = clean.unit
        book.totalUnits = clean.totalUnits
        books.touch(book, now: now)
        try books.save()
        return book
    }

    /// Rafa kaldırır (`archived: true`) ya da rafa geri alır.
    public func setArchived(_ book: Book, _ archived: Bool, now: Date = .now) throws {
        book.archivedAt = archived ? now : nil
        books.touch(book, now: now)
        try books.save()
    }

    /// Kitabı ve tüm ilerleme kayıtlarını soft-delete eder.
    public func delete(_ book: Book, now: Date = .now) throws {
        for entry in try progress.all() where entry.bookId == book.id {
            progress.softDelete(entry, now: now)
        }
        books.softDelete(book, now: now)
        try books.save()
    }

    // MARK: - İlerleme

    /// "Nereye kadar geldim" kaydı ekler. Toplamı aşabilir (hesap sınırlar); negatif olamaz.
    /// Kitabın `updatedAt`'i ilerletilmez: etkinlik zamanı zaten son ilerleme kaydından gelir.
    @discardableResult
    public func addProgress(
        bookId: UUID, reachedUnit: Int, note: String? = nil, now: Date = .now
    ) throws -> BookProgress {
        guard reachedUnit >= 0 else { throw BookValidationError.invalidReachedUnit }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let entry = progress.insert(
            BookProgress(
                bookId: bookId, reachedUnit: reachedUnit, recordedAt: now,
                note: trimmed.isEmpty ? nil : trimmed),
            now: now)
        try progress.save()
        return entry
    }

    /// Tek ilerleme kaydını siler.
    public func deleteProgress(_ entry: BookProgress, now: Date = .now) throws {
        progress.softDelete(entry, now: now)
        try progress.save()
    }

    // MARK: - İç

    private func exam(of subjectId: UUID?) throws -> ExamType? {
        guard let subjectId else { return nil }
        return try subjects.find(id: subjectId)?.exam
    }

    static func normalized(_ input: BookInput) throws -> BookInput {
        let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw BookValidationError.emptyTitle }
        if let total = input.totalUnits, total <= 0 { throw BookValidationError.invalidTotal }
        let publisher = input.publisher?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var clean = input
        clean.title = title
        clean.publisher = publisher.isEmpty ? nil : publisher
        return clean
    }
}
