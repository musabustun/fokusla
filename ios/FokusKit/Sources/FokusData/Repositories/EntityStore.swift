import Foundation
import SwiftData

/// Her varlık için ortak okuma/yazma (web `Repository<T>` karşılığı).
///
/// - Okumalar silinenleri (`deletedAt != nil`) varsayılan olarak hariç tutar.
/// - `id` CloudKit'te tekil zorlanamaz: aynı `id`'li kopyalarda en eski `createdAt` kazanır.
/// - Silme yalnızca `deletedAt` set eder (tombstone); kalıcı silme yok.
/// - Genel (generic) `#Predicate` protokol keypath'leriyle güvenilir çalışmadığından genel okumalar
///   bellekte filtreler; varlığa özel repository'ler somut `#Predicate` kullanır.
/// - SwiftUI ekranları okuma için doğrudan `@Query` kullanabilir; yazmalar repository üzerinden.
@MainActor
public struct EntityStore<Entity: SyncedEntity> {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Tüm kayıtlar (varsayılan: silinmemişler), `id` ile tekilleştirilmiş.
    public func all(includeDeleted: Bool = false) throws -> [Entity] {
        let fetched = try context.fetch(FetchDescriptor<Entity>())
        let visible = includeDeleted ? fetched : fetched.filter(\.isLive)
        return Self.deduplicated(visible)
    }

    /// `id` ile kayıt; silinmişse (`includeDeleted` değilse) `nil`.
    public func find(id: UUID, includeDeleted: Bool = false) throws -> Entity? {
        try all(includeDeleted: includeDeleted).first { $0.id == id }
    }

    /// Yeni kaydı ekler; `createdAt`/`updatedAt` doldurulur.
    @discardableResult
    public func insert(_ entity: Entity, now: Date = .now) -> Entity {
        entity.createdAt = now
        entity.updatedAt = now
        entity.deletedAt = nil
        context.insert(entity)
        return entity
    }

    /// Kayıt değiştirildikten sonra `updatedAt`'i ilerletir.
    public func touch(_ entity: Entity, now: Date = .now) {
        entity.updatedAt = now
    }

    /// Yumuşak silme (tombstone).
    public func softDelete(_ entity: Entity, now: Date = .now) {
        entity.deletedAt = now
        entity.updatedAt = now
    }

    /// Bekleyen değişiklikleri kaydeder.
    public func save() throws {
        if context.hasChanges { try context.save() }
    }

    /// Aynı `id`'li kopyalardan en eski `createdAt`'li olanı tutar; sıra korunur.
    static func deduplicated(_ entities: [Entity]) -> [Entity] {
        var winners: [UUID: Entity] = [:]
        for entity in entities {
            if let current = winners[entity.id], current.createdAt <= entity.createdAt { continue }
            winners[entity.id] = entity
        }
        return entities.filter { winners[$0.id] === $0 }
    }
}
