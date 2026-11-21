import Foundation
import SwiftData

/// Şema sürüm 1. CloudKit production şeması yalnızca EKLEMEYE izin verir: model/alan silme veya
/// yeniden adlandırma yok. Yeni alan → opsiyonel ya da varsayılanlı; yeni model → `models`'e ekle.
/// Kırıcı bir değişiklik gerekirse `FokusSchemaV2` + `FokusMigrationPlan.stages`.
public enum FokusSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            Subject.self,
            Topic.self,
            Book.self,
            BookProgress.self,
            TestResult.self,
            FocusSession.self,
            FocusSegment.self,
            StudyTask.self,
            TaskCompletion.self,
            Friend.self,
            Room.self,
        ]
    }
}

/// Göç planı. Şimdilik tek sürüm; aşama yok.
public enum FokusMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [FokusSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
