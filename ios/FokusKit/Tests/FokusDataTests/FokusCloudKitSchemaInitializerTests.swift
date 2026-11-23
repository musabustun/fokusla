#if DEBUG
import Foundation
import SwiftData
import Testing

@testable import FokusData

// CloudKit'e erişmeden: Core Data modeli SwiftData şemasındaki TÜM kayıt tiplerini içermeli.
// (`initializeCloudKitSchema` gerçek iCloud gerektirir; cihazda `ios/README.md` adımlarıyla çalıştırılır.)
struct FokusCloudKitSchemaInitializerTests {
    @Test func launchArgumentIsStable() {
        #expect(FokusCloudKitSchemaInitializer.launchArgument == "-FokusInitCloudKitSchema")
    }

    @Test func managedObjectModelCoversEverySchemaModel() throws {
        let model = try FokusCloudKitSchemaInitializer.makeManagedObjectModel()
        let swiftDataNames = Set(Schema(versionedSchema: FokusSchemaV1.self).entities.map(\.name))
        let coreDataNames = Set(model.entities.compactMap(\.name))
        #expect(coreDataNames == swiftDataNames)
        #expect(model.entities.count == FokusSchemaV1.models.count)
    }
}
#endif
