import Foundation
import SwiftData
import Testing

@testable import FokusData

// CloudKit kuralları (docs/ARCHITECTURE.md 4.4): unique yok, her özellik opsiyonel veya varsayılanlı.
struct SchemaCloudKitRulesTests {
    private var entities: [Schema.Entity] {
        Array(Schema(versionedSchema: FokusSchemaV1.self).entities)
    }

    @Test func entityNamesMatchDocumentedModels() {
        let names = Set(entities.map(\.name))
        #expect(
            names == [
                "UserProfile", "Subject", "Topic", "Book", "BookProgress", "TestResult",
                "FocusSession", "FocusSegment", "StudyTask", "TaskCompletion", "Friend", "Room",
            ]
        )
    }

    @Test func noAttributeIsUnique() {
        for entity in entities {
            for attribute in entity.attributes {
                #expect(!attribute.isUnique, "\(entity.name).\(attribute.name)")
            }
        }
    }

    @Test func everyAttributeIsOptionalOrHasDefault() {
        for entity in entities {
            for attribute in entity.attributes {
                #expect(
                    attribute.isOptional || attribute.defaultValue != nil,
                    "\(entity.name).\(attribute.name)"
                )
            }
        }
    }

    @Test func noRelationships() {
        for entity in entities { #expect(entity.relationships.isEmpty, "\(entity.name)") }
    }
}
