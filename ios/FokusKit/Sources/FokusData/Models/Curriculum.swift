import FokusDomain
import Foundation
import SwiftData

/// Ders (web `Subject`). Katalog dersleri `catalogKey != nil`, id'leri `catalogKey`'den UUID v5;
/// kullanıcı tanımlıları `catalogKey == nil`.
@Model
public final class Subject: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var name: String = ""
    public var examRaw: String = "TYT"
    public var fieldsRaw: [String] = []
    public var catalogKey: String?
    public var order: Int = 0

    public init(
        id: UUID = UUID(), name: String, exam: ExamType, fields: [YksField],
        catalogKey: String? = nil, order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.examRaw = exam.rawValue
        self.fieldsRaw = fields.map(\.rawValue)
        self.catalogKey = catalogKey
        self.order = order
    }

    public var exam: ExamType {
        get { ExamType(rawValue: examRaw) ?? .tyt }
        set { examRaw = newValue.rawValue }
    }

    /// Bilinmeyen raw value'lar atlanır.
    public var fields: [YksField] {
        get { fieldsRaw.compactMap(YksField.init(rawValue:)) }
        set { fieldsRaw = newValue.map(\.rawValue) }
    }
}

/// Konu (web `Topic`).
@Model
public final class Topic: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var subjectId: UUID?
    public var name: String = ""
    public var catalogKey: String?
    public var order: Int = 0

    public init(
        id: UUID = UUID(), subjectId: UUID?, name: String,
        catalogKey: String? = nil, order: Int = 0
    ) {
        self.id = id
        self.subjectId = subjectId
        self.name = name
        self.catalogKey = catalogKey
        self.order = order
    }
}
