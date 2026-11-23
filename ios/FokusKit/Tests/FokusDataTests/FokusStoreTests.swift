import Foundation
import SwiftData
import Testing

@testable import FokusData

struct FokusStoreTests {
    struct Case: Sendable {
        let id: String?
        let sync: Bool
        let icloud: Bool
        let expected: FokusStore.Mode
    }

    static let cases: [Case] = [
        Case(id: nil, sync: true, icloud: true, expected: .local),
        Case(id: "", sync: true, icloud: true, expected: .local),
        Case(id: "iCloud.x", sync: false, icloud: true, expected: .local),
        Case(id: "iCloud.x", sync: true, icloud: false, expected: .local),
        Case(id: "iCloud.x", sync: true, icloud: true, expected: .cloudKit(containerIdentifier: "iCloud.x")),
    ]

    @Test(arguments: cases)
    func preferredMode(_ testCase: Case) {
        let mode = FokusStore.preferredMode(
            containerIdentifier: testCase.id, syncEnabled: testCase.sync,
            iCloudAvailable: testCase.icloud
        )
        #expect(mode == testCase.expected)
    }

    @Test @MainActor func inMemoryContainerIsUsable() throws {
        let container = try FokusStore.makeInMemoryContainer()
        #expect(container.schema.entities.count == 13)
    }
}
