import Foundation

// Hesap fonksiyonlarının girdisi olan SAF değer tipleri. `Calc/` SwiftData'yı bilmez;
// FokusData'daki `@Model`'ler `.snapshot` ile bu tiplere dönüşür. Böylece hesaplar
// `Sendable`'dır, test edilir ve web vakaları birebir taşınır.
// Modül oturumları kendi hesapları için gereken snapshot'ları buraya EKLER (ör. TestResult).

/// `FocusSession`'ın hesaplar için gereken alanları.
public struct FocusSessionSnapshot: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var deletedAt: Date?

    public init(id: UUID, startedAt: Date, endedAt: Date? = nil, deletedAt: Date? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.deletedAt = deletedAt
    }
}

/// `FocusSegment`'in hesaplar için gereken alanları.
public struct FocusSegmentSnapshot: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var sessionId: UUID?
    public var kind: FocusSegmentKind
    public var startedAt: Date
    public var endedAt: Date?
    public var deletedAt: Date?

    public init(
        id: UUID, sessionId: UUID?, kind: FocusSegmentKind,
        startedAt: Date, endedAt: Date? = nil, deletedAt: Date? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.deletedAt = deletedAt
    }
}
