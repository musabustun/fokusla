import Foundation
import SwiftData
import Testing

@testable import FokusData

/// App Group taşıması: eski konumdaki depo hedefe taşınır, veri kaybolmaz, mevcut hedef ezilmez.
@MainActor
struct FokusAppGroupTests {
    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "fokus-appgroup-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeProfile(named name: String, at storeURL: URL) throws {
        let container = try FokusStore.makeContainer(mode: .local, storeURL: storeURL)
        container.mainContext.insert(UserProfile(displayName: name))
        try container.mainContext.save()
    }

    private func profileNames(at storeURL: URL) throws -> [String] {
        let container = try FokusStore.makeContainer(mode: .local, storeURL: storeURL)
        return try container.mainContext.fetch(FetchDescriptor<UserProfile>()).compactMap(\.displayName)
    }

    @Test func movesLegacyStoreAndKeepsData() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appending(path: "legacy/Fokus.store")
        let destination = FokusAppGroup.storeURL(in: root.appending(path: "group", directoryHint: .isDirectory))
        try FileManager.default.createDirectory(
            at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeProfile(named: "Ayşe", at: legacy)

        let result = try FokusAppGroup.migrateLegacyStoreIfNeeded(from: legacy, to: destination)

        #expect(result == .migrated)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        #expect(try profileNames(at: destination) == ["Ayşe"])
    }

    @Test func doesNotOverwriteExistingDestination() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appending(path: "legacy/Fokus.store")
        let destination = root.appending(path: "group/Fokus.store")
        for url in [legacy, destination] {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        try writeProfile(named: "Eski", at: legacy)
        try writeProfile(named: "Yeni", at: destination)

        let result = try FokusAppGroup.migrateLegacyStoreIfNeeded(from: legacy, to: destination)

        #expect(result == .notNeeded)
        #expect(FileManager.default.fileExists(atPath: legacy.path))
        #expect(try profileNames(at: destination) == ["Yeni"])
    }

    @Test func doesNothingWithoutLegacyStore() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appending(path: "group/Fokus.store")

        let result = try FokusAppGroup.migrateLegacyStoreIfNeeded(
            from: root.appending(path: "none/Fokus.store"), to: destination)

        #expect(result == .notNeeded)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func migrationIsIdempotent() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appending(path: "legacy/Fokus.store")
        let destination = root.appending(path: "group/Fokus.store")
        try FileManager.default.createDirectory(
            at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeProfile(named: "Ayşe", at: legacy)

        try FokusAppGroup.migrateLegacyStoreIfNeeded(from: legacy, to: destination)
        let second = try FokusAppGroup.migrateLegacyStoreIfNeeded(from: legacy, to: destination)

        #expect(second == .notNeeded)
        #expect(try profileNames(at: destination) == ["Ayşe"])
    }

    @Test func legacyStoreURLIsInsideOwnApplicationSupport() {
        let url = FokusStore.legacyStoreURL()
        #expect(url.lastPathComponent == "Fokus.store")
        #expect(url.deletingLastPathComponent().lastPathComponent == "Application Support")
    }

    @Test func storeURLUsesLegacyLayoutInsideContainer() {
        let url = FokusAppGroup.storeURL(in: URL(filePath: "/tmp/group"))
        #expect(url.path == "/tmp/group/Library/Application Support/Fokus.store")
    }
}
