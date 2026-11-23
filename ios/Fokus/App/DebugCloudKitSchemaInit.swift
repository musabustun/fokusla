#if DEBUG
import FokusData
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "cloudkit-schema")

/// Yalnızca DEBUG: uygulama `-FokusInitCloudKitSchema` ile başlatılınca CloudKit Development şemasını
/// başlatır (tüm `CD_*` kayıt tipleri). Gerçek depoya dokunmaz; arka planda çalışır, açılışı bekletmez
/// (watchdog). Sonuç `Logger` ile (`category: cloudkit-schema`) yazılır. Adımlar: `ios/README.md`.
enum DebugCloudKitSchemaInit {
    static let launchArgument = FokusCloudKitSchemaInitializer.launchArgument

    static func runIfRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        containerIdentifier: String? = Bundle.main.object(forInfoDictionaryKey: "FokusICloudContainer") as? String,
        iCloudAvailable: Bool = FileManager.default.ubiquityIdentityToken != nil
    ) {
        guard arguments.contains(launchArgument) else { return }
        guard let containerIdentifier, !containerIdentifier.isEmpty else {
            logger.error("Şema başlatılamadı: FokusICloudContainer tanımlı değil")
            return
        }
        guard iCloudAvailable else {
            logger.error("Şema başlatılamadı: cihazda iCloud hesabı yok (iCloud'a giriş yap)")
            return
        }
        logger.notice("CloudKit şeması başlatılıyor: \(containerIdentifier, privacy: .public)")
        // Senkron ve yavaş (ağ): ana iş parçacığını ve Swift eşzamanlılık havuzunu bloklamamak için GCD.
        DispatchQueue.global(qos: .utility).async {
            do {
                let summary = try FokusCloudKitSchemaInitializer.run(containerIdentifier: containerIdentifier)
                logger.notice(
                    "CloudKit şeması başlatıldı: \(summary.entityCount) kayıt tipi — \(summary.entityNames.joined(separator: ", "), privacy: .public)"
                )
            } catch {
                logger.error("CloudKit şeması başlatılamadı: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
#endif
