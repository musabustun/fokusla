import FokusDomain
import Foundation
import SwiftData

// SAHİBİ: katalog alt ajanı. Bu dosya yalnızca imza sözleşmesidir; implementasyon
// `Resources/yks-curriculum.json` kaynağından `Subject`/`Topic` tohumlar (web
// `ensureCurriculumSeeded` ile aynı davranış: idempotent, catalogKey eşleştirmesi, UUID v5 id).

/// Tohumlama sonucu (web `SeedResult`).
public struct SeedResult: Sendable, Equatable {
    public var subjectsCreated: Int
    public var topicsCreated: Int

    public init(subjectsCreated: Int, topicsCreated: Int) {
        self.subjectsCreated = subjectsCreated
        self.topicsCreated = topicsCreated
    }
}

@MainActor
public enum CurriculumSeeder {
    /// Müfredat kataloğunu idempotent biçimde tohumlar. Uygulama açılışında çağrılır.
    @discardableResult
    public static func ensureSeeded(context: ModelContext) throws -> SeedResult {
        SeedResult(subjectsCreated: 0, topicsCreated: 0)
    }
}
