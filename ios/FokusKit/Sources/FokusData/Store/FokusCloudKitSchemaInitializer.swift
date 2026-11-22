#if DEBUG
import CoreData
import Foundation
import SwiftData

/// Yalnızca DEBUG: CloudKit **Development** şemasını başlatır.
///
/// SwiftData kayıt tiplerini (`CD_<Model>`) yalnızca o tipten veri yazıldıkça oluşturur; bu yüzden yeni bir
/// ortamda bazı kayıt tipleri Console'da hiç görünmez ve Production'a deploy edilen şema eksik kalır.
/// Apple'ın önerdiği yol (bkz. "Syncing model data across a person's devices"): aynı modellerden bir
/// `NSManagedObjectModel` üretip `NSPersistentCloudKitContainer.initializeCloudKitSchema` çağırmak — bu,
/// Development'a örnek kayıtlar yazıp siler ve tüm kayıt tiplerini + alanlarını oluşturur.
///
/// Kullanıcının GERÇEK deposuna dokunmaz: geçici, ayrı bir depo dosyası kullanır ve işi bitince siler.
/// Release derlemesinde bu dosya derlenmez.
public enum FokusCloudKitSchemaInitializer {
    /// Başlatma argümanı (`xcrun devicectl device process launch … -- -FokusInitCloudKitSchema`).
    public static let launchArgument = "-FokusInitCloudKitSchema"

    /// Çalışmanın özeti (log için).
    public struct Summary: Sendable, Equatable {
        /// Şemaya katılan kayıt tipi (entity) sayısı; `FokusSchemaV1.models` sayısına eşit olmalı.
        public let entityCount: Int
        /// Entity adları (CloudKit'te `CD_` önekiyle görünür), alfabetik.
        public let entityNames: [String]
    }

    public enum InitializerError: Error, Equatable {
        case managedObjectModelUnavailable
        case storeLoadFailed(String)
    }

    /// `FokusSchemaV1.models` modellerinden Core Data modeli. SwiftData ile aynı kayıt tiplerini üretir.
    public static func makeManagedObjectModel() throws -> NSManagedObjectModel {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: FokusSchemaV1.models) else {
            throw InitializerError.managedObjectModelUnavailable
        }
        return model
    }

    /// Şemayı başlatır. SENKRON ve yavaştır (ağ; onlarca saniye sürebilir): ana iş parçacığında çağırma.
    /// Cihazda iCloud hesabı açık olmalıdır; aksi halde Core Data hata fırlatır.
    @discardableResult
    public static func run(
        containerIdentifier: String, fileManager: FileManager = .default
    ) throws -> Summary {
        let model = try makeManagedObjectModel()
        let summary = Summary(
            entityCount: model.entities.count, entityNames: model.entities.compactMap(\.name).sorted())

        // Ayrı, geçici depo: gerçek `Fokus.store` ile aynı dosyayı paylaşmayız (ikisi birden CloudKit'e
        // eşlemeye çalışmasın). Dizin her çalıştırmada yeni olduğundan eski kalıntıdan etkilenmez.
        let directory = fileManager.temporaryDirectory.appending(
            path: "FokusSchemaInit-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let description = NSPersistentStoreDescription(
            url: directory.appending(path: "SchemaInit.store", directoryHint: .notDirectory))
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: containerIdentifier)
        // Depo, şema başlatılmadan ÖNCE yüklenmiş olmalı.
        description.shouldAddStoreAsynchronously = false

        let container = NSPersistentCloudKitContainer(name: "FokusSchemaInit", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            throw InitializerError.storeLoadFailed(loadError.localizedDescription)
        }

        // Her durumda depoyu çıkar: dosyalar silinmeden önce kapanmış olsun, SwiftData yığınıyla çakışmasın.
        defer {
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
        }
        try container.initializeCloudKitSchema(options: [])
        return summary
    }
}
#endif
