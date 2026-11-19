import Foundation
import SwiftData

/// `ModelContainer` kurulumu. Uygulama açılışta bir kez kurar ve `.modelContainer(_:)` ile verir.
public enum FokusStore {
    /// Depolama biçimi.
    public enum Mode: Sendable, Equatable {
        /// SwiftData + CloudKit private database otomatik mirroring.
        case cloudKit(containerIdentifier: String)
        /// Yalnızca cihazda (iCloud yok / senkron kapalı / imzasız simülatör derlemesi).
        case local
        /// Bellek içi (testler, önizlemeler, UI testleri).
        case inMemory
    }

    /// Kalıcı deponun adı. Değiştirmek mevcut kullanıcı verisini "kaybettirir" — DEĞİŞTİRME.
    public static let storeName = "Fokus"

    /// Hangi modun kullanılacağına karar verir (saf; test edilir).
    /// CloudKit yalnızca kapsayıcı kimliği tanımlıysa, kullanıcı senkronu kapatmadıysa ve cihazda
    /// iCloud hesabı varsa (`FileManager.ubiquityIdentityToken != nil`) seçilir.
    public static func preferredMode(
        containerIdentifier: String?,
        syncEnabled: Bool,
        iCloudAvailable: Bool
    ) -> Mode {
        guard let containerIdentifier, !containerIdentifier.isEmpty, syncEnabled, iCloudAvailable else {
            return .local
        }
        return .cloudKit(containerIdentifier: containerIdentifier)
    }

    /// Verilen modda container kurar.
    public static func makeContainer(mode: Mode) throws -> ModelContainer {
        let schema = Schema(versionedSchema: FokusSchemaV1.self)
        let configuration: ModelConfiguration
        switch mode {
        case let .cloudKit(identifier):
            configuration = ModelConfiguration(
                storeName, schema: schema, cloudKitDatabase: .private(identifier)
            )
        case .local:
            configuration = ModelConfiguration(storeName, schema: schema, cloudKitDatabase: .none)
        case .inMemory:
            configuration = ModelConfiguration(
                schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
            )
        }
        return try ModelContainer(
            for: schema, migrationPlan: FokusMigrationPlan.self, configurations: [configuration]
        )
    }

    /// Önizleme ve testler için bellek içi container.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(mode: .inMemory)
    }
}
