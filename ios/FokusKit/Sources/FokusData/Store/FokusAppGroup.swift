import Foundation

/// Uygulama ile widget/Live Activity/App Intents uzantılarının ORTAK depoyu kullanması için App Group
/// yardımcıları. Depo dosyası (`Fokus.store` + `-wal` + `-shm`) App Group kapsayıcısına taşınır; CloudKit
/// yapılandırması aynı kalır (dosya konumu değişir, kayıt tipleri ve geçmiş izleme dosyanın içindedir).
public enum FokusAppGroup {
    /// Yalnızca projede tanımlıdır (entitlements); Apple Developer hesabında ayrıca kaydedilmelidir.
    public static let identifier = "group.com.musabustun.fokus"

    /// Depo dosyasının uzantıları (SQLite + WAL).
    private static let sidecarSuffixes = ["", "-wal", "-shm"]

    /// App Group kapsayıcısı; yetki yoksa (imzasız simülatör derlemesi, testler) `nil`.
    public static func containerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Kapsayıcıdaki depo dosyası: `<group>/Library/Application Support/Fokus.store` (eski konumla aynı yerleşim).
    public static func storeURL(in container: URL) -> URL {
        container.appending(path: "Library/Application Support", directoryHint: .isDirectory)
            .appending(path: "\(FokusStore.storeName).store", directoryHint: .notDirectory)
    }

    public enum MigrationResult: Sendable, Equatable {
        /// Eski depo yoktu ya da hedef zaten vardı: yapılacak bir şey yok.
        case notNeeded
        /// Eski depo (ve yan dosyaları) hedefe taşındı.
        case migrated
    }

    /// Eski konumdaki depo varsa ve hedefte henüz depo YOKSA dosyaları hedefe taşır (önce kopyala,
    /// hepsi başarılıysa eskileri sil; hata olursa yarım kopyayı geri alır ve eski depoyu olduğu gibi bırakır).
    /// Hedef zaten varsa üzerine YAZMAZ: kullanıcı verisi asla ezilmez.
    /// Depo AÇIKKEN çağrılmamalıdır (container kurulmadan önce, açılışta).
    @discardableResult
    public static func migrateLegacyStoreIfNeeded(
        from legacy: URL, to destination: URL, fileManager: FileManager = .default
    ) throws -> MigrationResult {
        guard fileManager.fileExists(atPath: legacy.path),
            !fileManager.fileExists(atPath: destination.path),
            legacy.standardizedFileURL != destination.standardizedFileURL
        else { return .notNeeded }

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        var copied: [URL] = []
        do {
            for suffix in sidecarSuffixes {
                let source = URL(fileURLWithPath: legacy.path + suffix)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                let target = URL(fileURLWithPath: destination.path + suffix)
                try fileManager.copyItem(at: source, to: target)
                copied.append(target)
            }
        } catch {
            copied.forEach { try? fileManager.removeItem(at: $0) }
            throw error
        }
        for suffix in sidecarSuffixes {
            try? fileManager.removeItem(at: URL(fileURLWithPath: legacy.path + suffix))
        }
        return .migrated
    }

    /// Uygulamanın kullanacağı depo dosyası: App Group varsa (gerekirse eski depoyu taşıyarak) oradaki
    /// dosya; yoksa `nil` (varsayılan konum, mevcut davranış).
    public static func resolveStoreURL(fileManager: FileManager = .default) -> URL? {
        guard let container = containerURL(fileManager: fileManager) else { return nil }
        let destination = storeURL(in: container)
        do {
            try migrateLegacyStoreIfNeeded(
                from: FokusStore.legacyStoreURL(fileManager: fileManager), to: destination, fileManager: fileManager)
        } catch {
            // Taşıma başarısız: eski depo yerinde kaldı; veri kaybetmemek için varsayılan konumu kullan.
            return nil
        }
        return destination
    }
}
