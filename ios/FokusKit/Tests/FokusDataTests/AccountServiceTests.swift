import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

@MainActor
struct AccountServiceTests {
    private func make(
        appleUserId: String? = nil, displayName: String? = nil, revoker: MockAppleTokenRevoker = MockAppleTokenRevoker(),
        syncEnabled: Bool = true
    ) throws -> (AccountService, ProfileRepository, MockSyncService, MockAppleTokenRevoker) {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        let repository = ProfileRepository(context: context)
        try repository.completeOnboarding(field: .say, appleUserId: appleUserId, displayName: displayName)
        let sync = MockSyncService(status: syncEnabled ? .idle : .disabled, isEnabled: syncEnabled)
        return (AccountService(context: context, sync: sync, revoker: revoker), repository, sync, revoker)
    }

    @Test func linkStoresAppleIdAndFillsMissingName() throws {
        let (service, repository, _, _) = try make()
        try service.link(AppleSignInIdentity(userId: "apple-1", displayName: "Ada Lovelace"))
        #expect(try repository.current()?.appleUserId == "apple-1")
        #expect(try repository.current()?.displayName == "Ada Lovelace")
    }

    @Test func linkKeepsExistingName() throws {
        let (service, repository, _, _) = try make(displayName: "Ada")
        try service.link(AppleSignInIdentity(userId: "apple-1", displayName: "Başka"))
        #expect(try repository.current()?.displayName == "Ada")
    }

    @Test func signOutUnlinksDisablesSyncAndKeepsData() throws {
        let (service, repository, sync, _) = try make(appleUserId: "apple-1", displayName: "Ada")
        try service.signOut()
        #expect(try repository.current()?.appleUserId == nil)
        #expect(try repository.current()?.displayName == "Ada")
        #expect(sync.isEnabled == false)
    }

    @Test func deleteAccountRevokedWhenRevokerSucceeds() async throws {
        let (service, repository, sync, revoker) = try make(appleUserId: "apple-1")
        let outcome = try await service.deleteAccount()
        #expect(outcome == .revoked)
        #expect(revoker.revokedUserIds == ["apple-1"])
        #expect(try repository.current()?.appleUserId == nil)
        #expect(sync.isEnabled == false)
    }

    @Test func deleteAccountAsksForManualRevocationWhenRevokerCannot() async throws {
        let (service, repository, _, _) = try make(appleUserId: "apple-1", revoker: MockAppleTokenRevoker(result: false))
        #expect(try await service.deleteAccount() == .manualRevocationNeeded)
        #expect(try repository.current()?.appleUserId == nil)
        #expect(try repository.current() != nil)
    }

    @Test func manualRevokerNeverRevokes() async {
        #expect(await ManualAppleTokenRevoker().revoke(appleUserId: "x") == false)
    }

    @Test func deleteAccountWithoutLinkDoesNothing() async throws {
        let (service, _, _, revoker) = try make()
        #expect(try await service.deleteAccount() == .nothingLinked)
        #expect(revoker.revokedUserIds.isEmpty)
    }
}
