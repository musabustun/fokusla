import FokusDomain
import Foundation
import SwiftData

/// Odak oturumu (web `FocusSession`). Süreler segmentlerden hesaplanır, saklanmaz.
@Model
public final class FocusSession: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var subjectId: UUID?
    public var topicId: UUID?
    public var startedAt: Date = Date.now
    public var endedAt: Date?
    public var note: String?

    public init(
        id: UUID = UUID(), subjectId: UUID? = nil, topicId: UUID? = nil,
        startedAt: Date = .now, endedAt: Date? = nil, note: String? = nil
    ) {
        self.id = id
        self.subjectId = subjectId
        self.topicId = topicId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
    }

    /// Hesaplar (`FocusCalc`) için değer kopyası.
    public var snapshot: FocusSessionSnapshot {
        FocusSessionSnapshot(id: id, startedAt: startedAt, endedAt: endedAt, deletedAt: deletedAt)
    }
}

/// Odak/mola aralığı (web `FocusSegment`).
@Model
public final class FocusSegment: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var sessionId: UUID?
    public var kindRaw: String = "focus"
    public var startedAt: Date = Date.now
    public var endedAt: Date?

    public init(
        id: UUID = UUID(), sessionId: UUID?, kind: FocusSegmentKind,
        startedAt: Date = .now, endedAt: Date? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.kindRaw = kind.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    public var kind: FocusSegmentKind {
        get { FocusSegmentKind(rawValue: kindRaw) ?? .focus }
        set { kindRaw = newValue.rawValue }
    }

    /// Hesaplar (`FocusCalc`) için değer kopyası.
    public var snapshot: FocusSegmentSnapshot {
        FocusSegmentSnapshot(
            id: id, sessionId: sessionId, kind: kind,
            startedAt: startedAt, endedAt: endedAt, deletedAt: deletedAt
        )
    }
}
