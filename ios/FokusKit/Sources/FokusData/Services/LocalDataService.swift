import FokusDomain
import Foundation
import SwiftData

/// Cihazdaki verinin bütününe dair işlemler (web `LocalDataService`): JSON dışa aktarma ve tümünü
/// silme (Ayarlar > Veri). Dışa aktarma biçimi web ile birebir aynıdır (`formatVersion` 1).
@MainActor
public struct LocalDataService {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Silinmemiş (id ile tekilleştirilmiş) TÜM kayıtların, web dışa aktarmasıyla aynı biçimde,
    /// girintili ve anahtarları sıralı JSON'u. Kimlik bilgisi içermez.
    public func exportJSON(now: Date = .now) throws -> Data {
        let document = DataExportDocument(
            exportedAt: ExportFormat.dateTime(now),
            entities: DataExportDocument.Entities(
                profiles: try live(UserProfile.self).map(ProfileDTO.init),
                subjects: try live(Subject.self).map(SubjectDTO.init),
                topics: try live(Topic.self).map(TopicDTO.init),
                books: try live(Book.self).map(BookDTO.init),
                bookProgress: try live(BookProgress.self).map(BookProgressDTO.init),
                testResults: try live(TestResult.self).map(TestResultDTO.init),
                focusSessions: try live(FocusSession.self).map(FocusSessionDTO.init),
                focusSegments: try live(FocusSegment.self).map(FocusSegmentDTO.init),
                tasks: try live(StudyTask.self).map(TaskDTO.init),
                taskCompletions: try live(TaskCompletion.self).map(TaskCompletionDTO.init),
                friends: try live(Friend.self).map(FriendDTO.init),
                rooms: try live(Room.self).map(RoomDTO.init)))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    /// Önerilen dosya adı: `fokus-yedek-YYYY-MM-DD.json` (yerel gün).
    public static func exportFileName(now: Date = .now, calendar: Calendar = .current) -> String {
        "fokus-yedek-\(Identifiers.isoDate(now, calendar: calendar)).json"
    }

    /// 12 varlığın TÜM kayıtlarını KALICI olarak siler (tombstone'lar dahil) ve kaydeder.
    /// Müfredat kataloğunu yeniden tohumlamak çağıranın işidir. Geri alınamaz; senkron açıksa silme
    /// iCloud'a da yansıyabilir.
    public func deleteAll() throws {
        try context.delete(model: UserProfile.self)
        try context.delete(model: Subject.self)
        try context.delete(model: Topic.self)
        try context.delete(model: Book.self)
        try context.delete(model: BookProgress.self)
        try context.delete(model: TestResult.self)
        try context.delete(model: FocusSession.self)
        try context.delete(model: FocusSegment.self)
        try context.delete(model: StudyTask.self)
        try context.delete(model: TaskCompletion.self)
        try context.delete(model: Friend.self)
        try context.delete(model: Room.self)
        try context.save()
    }

    /// Silinmemiş, tekilleştirilmiş kayıtlar; çıktı kararlı olsun diye `createdAt`, sonra `id` ile sıralı.
    private func live<Entity: SyncedEntity>(_ type: Entity.Type) throws -> [Entity] {
        try EntityStore<Entity>(context: context).all().sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return Identifiers.lowercasedString($0.id) < Identifiers.lowercasedString($1.id)
        }
    }
}
