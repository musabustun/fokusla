import FokusDomain
import Foundation
import SwiftData

/// Kitap (web `Book`). Sahibi: books modülü.
@Model
public final class Book: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var title: String = ""
    public var publisher: String?
    public var kindRaw: String = "other"
    public var subjectId: UUID?
    public var examRaw: String?
    public var unitRaw: String = "page"
    public var totalUnits: Int?
    public var archivedAt: Date?
    /// Normalize EAN-13 barkodu (yalnızca rakam); barkodsuz kitapta `nil`.
    public var barcode: String?
    /// Gömülü kitap kataloğundaki kaydın kalıcı anahtarı; katalogdan gelmeyen kitapta `nil`.
    public var libraryKey: String?

    public init(
        id: UUID = UUID(), title: String, publisher: String? = nil, kind: BookKind = .other,
        subjectId: UUID? = nil, exam: ExamType? = nil, unit: BookUnit = .page,
        totalUnits: Int? = nil, archivedAt: Date? = nil,
        barcode: String? = nil, libraryKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.publisher = publisher
        self.kindRaw = kind.rawValue
        self.subjectId = subjectId
        self.examRaw = exam?.rawValue
        self.unitRaw = unit.rawValue
        self.totalUnits = totalUnits
        self.archivedAt = archivedAt
        self.barcode = barcode
        self.libraryKey = libraryKey
    }

    public var kind: BookKind {
        get { BookKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    public var exam: ExamType? {
        get { examRaw.flatMap(ExamType.init(rawValue:)) }
        set { examRaw = newValue?.rawValue }
    }

    public var unit: BookUnit {
        get { BookUnit(rawValue: unitRaw) ?? .page }
        set { unitRaw = newValue.rawValue }
    }
}

/// Kitapta gelinen yer kaydı (web `BookProgress`).
@Model
public final class BookProgress: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var bookId: UUID?
    public var reachedUnit: Int = 0
    public var topicId: UUID?
    public var recordedAt: Date = Date.now
    public var note: String?

    public init(
        id: UUID = UUID(), bookId: UUID?, reachedUnit: Int, topicId: UUID? = nil,
        recordedAt: Date = .now, note: String? = nil
    ) {
        self.id = id
        self.bookId = bookId
        self.reachedUnit = reachedUnit
        self.topicId = topicId
        self.recordedAt = recordedAt
        self.note = note
    }
}

/// Kitabın bir bölümü/ünitesi (web `BookSection`). `order` kitap içindeki sıradır.
@Model
public final class BookSection: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var bookId: UUID?
    public var title: String = ""
    public var order: Int = 0
    public var startUnit: Int?
    public var endUnit: Int?
    public var topicId: UUID?

    public init(
        id: UUID = UUID(), bookId: UUID?, title: String, order: Int, startUnit: Int? = nil,
        endUnit: Int? = nil, topicId: UUID? = nil
    ) {
        self.id = id
        self.bookId = bookId
        self.title = title
        self.order = order
        self.startUnit = startUnit
        self.endUnit = endUnit
        self.topicId = topicId
    }
}
