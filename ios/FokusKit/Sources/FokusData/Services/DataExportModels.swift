import FokusDomain
import Foundation

// Web dışa aktarma biçiminin (`web/src/data/localData.ts` → `DataExport`) `Encodable` aynası.
// Alan adları ve enum raw value'ları `web/src/domain/types.ts` ile birebir aynıdır. Nil opsiyoneller
// atlanmaz, açık `null` olarak yazılır (web şekli) — bunu `@ExplicitNull` sağlar.

/// Sentezlenmiş `Encodable` nil değerleri atlar; bu sarmalayıcı onları `null` yazar.
@propertyWrapper
struct ExplicitNull<Value: Encodable>: Encodable {
    var wrappedValue: Value?

    init(wrappedValue: Value?) { self.wrappedValue = wrappedValue }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value = wrappedValue {
            try container.encode(value)
        } else {
            try container.encodeNil()
        }
    }
}

/// `Date` → `2026-11-19T07:30:00.000Z` (UTC, milisaniyeli) ve UUID → küçük harfli dizge.
enum ExportFormat {
    static func dateTime(_ date: Date) -> String {
        // Formatter'lar thread-safe olmadığından çağrı başına kurulur (dışa aktarma seyrek bir iştir).
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    static func dateTime(_ date: Date?) -> String? { date.map { dateTime($0) } }

    static func id(_ id: UUID) -> String { Identifiers.lowercasedString(id) }

    static func id(_ id: UUID?) -> String? { id.map { Identifiers.lowercasedString($0) } }
}

/// Üst düzey yedek dosyası (web `DataExport`).
struct DataExportDocument: Encodable {
    var app = "fokus"
    var formatVersion = 1
    var exportedAt: String
    var entities: Entities

    struct Entities: Encodable {
        var profiles: [ProfileDTO]
        var subjects: [SubjectDTO]
        var topics: [TopicDTO]
        var books: [BookDTO]
        var bookProgress: [BookProgressDTO]
        var bookSections: [BookSectionDTO]
        var testResults: [TestResultDTO]
        var focusSessions: [FocusSessionDTO]
        var focusSegments: [FocusSegmentDTO]
        var tasks: [TaskDTO]
        var taskCompletions: [TaskCompletionDTO]
        var friends: [FriendDTO]
        var rooms: [RoomDTO]
    }
}

struct ProfileDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    @ExplicitNull var displayName: String?
    var field: String
    @ExplicitNull var appleUserId: String?
    @ExplicitNull var targetExamYear: Int?
    @ExplicitNull var onboardingCompletedAt: String?
    @ExplicitNull var dailyFocusGoalMinutes: Int?

    init(_ m: UserProfile) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        displayName = m.displayName
        field = m.fieldRaw
        appleUserId = m.appleUserId
        targetExamYear = m.targetExamYear
        onboardingCompletedAt = ExportFormat.dateTime(m.onboardingCompletedAt)
        dailyFocusGoalMinutes = m.dailyFocusGoalMinutes
    }
}

struct SubjectDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    var name: String
    var exam: String
    var fields: [String]
    @ExplicitNull var catalogKey: String?
    var order: Int

    init(_ m: Subject) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        name = m.name
        exam = m.examRaw
        fields = m.fieldsRaw
        catalogKey = m.catalogKey
        order = m.order
    }
}

struct TopicDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    @ExplicitNull var subjectId: String?
    var name: String
    @ExplicitNull var catalogKey: String?
    var order: Int

    init(_ m: Topic) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        subjectId = ExportFormat.id(m.subjectId)
        name = m.name
        catalogKey = m.catalogKey
        order = m.order
    }
}

struct BookDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    var title: String
    @ExplicitNull var publisher: String?
    var kind: String
    @ExplicitNull var subjectId: String?
    @ExplicitNull var exam: String?
    var unit: String
    @ExplicitNull var totalUnits: Int?
    @ExplicitNull var archivedAt: String?
    @ExplicitNull var barcode: String?
    @ExplicitNull var libraryKey: String?

    init(_ m: Book) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        title = m.title
        publisher = m.publisher
        kind = m.kindRaw
        subjectId = ExportFormat.id(m.subjectId)
        exam = m.examRaw
        unit = m.unitRaw
        totalUnits = m.totalUnits
        archivedAt = ExportFormat.dateTime(m.archivedAt)
        barcode = m.barcode
        libraryKey = m.libraryKey
    }
}

struct BookSectionDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    @ExplicitNull var bookId: String?
    var title: String
    var order: Int
    @ExplicitNull var startUnit: Int?
    @ExplicitNull var endUnit: Int?
    @ExplicitNull var topicId: String?

    init(_ m: BookSection) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        bookId = ExportFormat.id(m.bookId)
        title = m.title
        order = m.order
        startUnit = m.startUnit
        endUnit = m.endUnit
        topicId = ExportFormat.id(m.topicId)
    }
}

struct BookProgressDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    @ExplicitNull var bookId: String?
    var reachedUnit: Int
    @ExplicitNull var topicId: String?
    var recordedAt: String
    @ExplicitNull var note: String?

    init(_ m: BookProgress) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        bookId = ExportFormat.id(m.bookId)
        reachedUnit = m.reachedUnit
        topicId = ExportFormat.id(m.topicId)
        recordedAt = ExportFormat.dateTime(m.recordedAt)
        note = m.note
    }
}

struct TestResultDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    @ExplicitNull var subjectId: String?
    @ExplicitNull var topicId: String?
    @ExplicitNull var bookId: String?
    @ExplicitNull var label: String?
    @ExplicitNull var sourceName: String?
    var takenAt: String
    var correct: Int
    var wrong: Int
    var blank: Int
    @ExplicitNull var durationSeconds: Int?
    @ExplicitNull var note: String?

    init(_ m: TestResult) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        subjectId = ExportFormat.id(m.subjectId)
        topicId = ExportFormat.id(m.topicId)
        bookId = ExportFormat.id(m.bookId)
        label = m.label
        sourceName = m.sourceName
        takenAt = ExportFormat.dateTime(m.takenAt)
        correct = m.correct
        wrong = m.wrong
        blank = m.blank
        durationSeconds = m.durationSeconds
        note = m.note
    }
}

struct FocusSessionDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    @ExplicitNull var subjectId: String?
    @ExplicitNull var topicId: String?
    var startedAt: String
    @ExplicitNull var endedAt: String?
    @ExplicitNull var note: String?

    init(_ m: FocusSession) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        subjectId = ExportFormat.id(m.subjectId)
        topicId = ExportFormat.id(m.topicId)
        startedAt = ExportFormat.dateTime(m.startedAt)
        endedAt = ExportFormat.dateTime(m.endedAt)
        note = m.note
    }
}

struct FocusSegmentDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    @ExplicitNull var sessionId: String?
    var kind: String
    var startedAt: String
    @ExplicitNull var endedAt: String?

    init(_ m: FocusSegment) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        sessionId = ExportFormat.id(m.sessionId)
        kind = m.kindRaw
        startedAt = ExportFormat.dateTime(m.startedAt)
        endedAt = ExportFormat.dateTime(m.endedAt)
    }
}

struct TaskDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    var title: String
    var kind: String
    @ExplicitNull var notes: String?
    @ExplicitNull var subjectId: String?
    @ExplicitNull var dueDate: String?
    @ExplicitNull var recurrence: RecurrenceRule?
    @ExplicitNull var completedAt: String?
    var order: Int
    @ExplicitNull var startDate: String?
    @ExplicitNull var targetQuantity: Int?
    @ExplicitNull var quantityUnit: String?
    @ExplicitNull var completedQuantity: Int?

    init(_ m: StudyTask) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        title = m.title
        kind = m.kindRaw
        notes = m.notes
        subjectId = ExportFormat.id(m.subjectId)
        dueDate = m.dueDate
        recurrence = m.recurrence
        completedAt = ExportFormat.dateTime(m.completedAt)
        order = m.order
        startDate = m.startDate
        targetQuantity = m.targetQuantity
        quantityUnit = m.quantityUnit
        completedQuantity = m.completedQuantity
    }
}

struct TaskCompletionDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    @ExplicitNull var taskId: String?
    var date: String
    var completedAt: String
    @ExplicitNull var quantity: Int?

    init(_ m: TaskCompletion) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        taskId = ExportFormat.id(m.taskId)
        date = m.date
        completedAt = ExportFormat.dateTime(m.completedAt)
        quantity = m.quantity
    }
}

struct FriendDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    var remoteUserId: String
    var displayName: String
    var status: String

    init(_ m: Friend) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        remoteUserId = m.remoteUserId
        displayName = m.displayName
        status = m.statusRaw
    }
}

struct RoomDTO: Encodable {
    var id: String
    var createdAt: String
    var updatedAt: String
    @ExplicitNull var deletedAt: String?
    var name: String
    var hostUserId: String
    var memberUserIds: [String]
    var inviteCode: String
    @ExplicitNull var startedAt: String?
    @ExplicitNull var endedAt: String?

    init(_ m: Room) {
        id = ExportFormat.id(m.id)
        createdAt = ExportFormat.dateTime(m.createdAt)
        updatedAt = ExportFormat.dateTime(m.updatedAt)
        deletedAt = nil
        name = m.name
        hostUserId = m.hostUserId
        memberUserIds = m.memberUserIds
        inviteCode = m.inviteCode
        startedAt = ExportFormat.dateTime(m.startedAt)
        endedAt = ExportFormat.dateTime(m.endedAt)
    }
}
