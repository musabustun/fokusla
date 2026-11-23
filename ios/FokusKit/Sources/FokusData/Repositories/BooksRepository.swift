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
    /// Normalize EAN-13 barkodu; yoksa `nil`.
    public var barcode: String?
    /// Gömülü katalog kaydının kalıcı anahtarı; yoksa `nil`.
    public var libraryKey: String?

    public init(
        title: String, publisher: String? = nil, kind: BookKind = .questionBank,
        subjectId: UUID? = nil, unit: BookUnit = .test, totalUnits: Int? = nil,
        barcode: String? = nil, libraryKey: String? = nil
    ) {
        self.title = title
        self.publisher = publisher
        self.kind = kind
        self.subjectId = subjectId
        self.unit = unit
        self.totalUnits = totalUnits
        self.barcode = barcode
        self.libraryKey = libraryKey
    }
}

/// Bir kitap bölümünün girdisi (web `BookSection`).
public struct BookSectionInput: Sendable, Equatable {
    public var title: String
    public var order: Int
    public var startUnit: Int?
    public var endUnit: Int?
    public var topicId: UUID?

    public init(
        title: String, order: Int, startUnit: Int? = nil, endUnit: Int? = nil, topicId: UUID? = nil
    ) {
        self.title = title
        self.order = order
        self.startUnit = startUnit
        self.endUnit = endUnit
        self.topicId = topicId
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
    private let sections: EntityStore<BookSection>
    private let subjects: EntityStore<Subject>

    public init(context: ModelContext) {
        sections = EntityStore(context: context)
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
                unit: clean.unit, totalUnits: clean.totalUnits, barcode: clean.barcode,
                libraryKey: clean.libraryKey),
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
        book.barcode = clean.barcode
        book.libraryKey = clean.libraryKey
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

    /// Aynı barkodlu silinmemiş kitap; birden çoksa en eski `createdAt`.
    public func book(withBarcode barcode: String) throws -> Book? {
        try books.all().filter { $0.barcode == barcode }.min { $0.createdAt < $1.createdAt }
    }

    /// Kitabı, tüm ilerleme kayıtlarını ve bölümlerini soft-delete eder.
    public func delete(_ book: Book, now: Date = .now) throws {
        for entry in try progress.all() where entry.bookId == book.id {
            progress.softDelete(entry, now: now)
        }
        for section in try sections.all() where section.bookId == book.id {
            sections.softDelete(section, now: now)
        }
        books.softDelete(book, now: now)
        try books.save()
    }

    // MARK: - Bölümler

    /// Kitabın silinmemiş bölümleri, `order`'a göre artan.
    public func sections(of bookId: UUID) throws -> [BookSection] {
        try sections.all().filter { $0.bookId == bookId }.sorted { $0.order < $1.order }
    }

    /// Kitabın bölümlerini değiştirir: eskiler soft-delete edilir, girdilerden yenileri oluşturulur.
    public func replaceSections(
        _ inputs: [BookSectionInput], for book: Book, now: Date = .now
    ) throws {
        for old in try sections(of: book.id) { sections.softDelete(old, now: now) }
        for input in inputs {
            let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
            sections.insert(
                BookSection(
                    bookId: book.id, title: title, order: input.order, startUnit: input.startUnit,
                    endUnit: input.endUnit, topicId: input.topicId),
                now: now)
        }
        try sections.save()
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
