import FokusData
import Foundation

/// `@Query` sonuçları için ortak yardımcılar.
enum TodayData {
    /// Aynı `id`'li kopyalarda en eski `createdAt` kazanır (CloudKit); sıra korunur.
    static func deduplicated<T: SyncedEntity>(_ entities: [T]) -> [T] {
        var winners: [UUID: T] = [:]
        for entity in entities {
            if let current = winners[entity.id], current.createdAt <= entity.createdAt { continue }
            winners[entity.id] = entity
        }
        return entities.filter { winners[$0.id] === $0 }
    }
}
