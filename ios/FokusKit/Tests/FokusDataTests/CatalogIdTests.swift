import FokusDomain
import Foundation
import Testing

@testable import FokusData

// Web `catalogEntityId` doğruluk kaynağıdır; Fixtures/catalog-ids.web.json onunla üretilir.
struct CatalogIdTests {
    static func webIds() throws -> [String: String] {
        let url = try #require(
            Bundle.module.url(
                forResource: "catalog-ids.web", withExtension: "json", subdirectory: "Fixtures"
            )
        )
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }

    @Test func everyWebIdMatchesSwiftId() throws {
        let ids = try Self.webIds()
        #expect(!ids.isEmpty)
        for (key, webId) in ids {
            #expect(Identifiers.lowercasedString(Identifiers.catalogEntityId(key)) == webId, "\(key)")
        }
    }

    @Test func everyBundledCatalogKeyIsInFixture() throws {
        let ids = try Self.webIds()
        let catalog = try CurriculumCatalog.bundled()
        var keys: [String] = []
        for subject in catalog.subjects {
            keys.append(subject.key)
            keys.append(contentsOf: subject.topics.map(\.key))
        }
        for key in keys { #expect(ids[key] != nil, "\(key)") }
        #expect(Set(keys) == Set(ids.keys))
    }

    @Test func uuidV5MatchesRfcVector() throws {
        let dns = try #require(UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8"))
        let id = Identifiers.uuidV5(name: "python.org", namespace: dns)
        #expect(Identifiers.lowercasedString(id) == "886313e1-3b8a-5372-9b90-0c9aee199e5d")
    }
}
