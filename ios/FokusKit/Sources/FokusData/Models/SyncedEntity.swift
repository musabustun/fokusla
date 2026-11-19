import Foundation
import SwiftData

/// Her `@Model`'in taşıdığı ortak alanlar (web `BaseEntity`).
///
/// CloudKit kuralları (docs/ARCHITECTURE.md 4.4): `@Attribute(.unique)` YOK, her özellik opsiyonel
/// veya varsayılanlı, ilişki yerine düz `UUID?` yabancı anahtar. Silme = `deletedAt` (tombstone).
public protocol SyncedEntity: PersistentModel {
    var id: UUID { get set }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}

extension SyncedEntity {
    /// Silinmemiş (tombstone olmayan) kayıt mı?
    public var isLive: Bool { deletedAt == nil }
}
