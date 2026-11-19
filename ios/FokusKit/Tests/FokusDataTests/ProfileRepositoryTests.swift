import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

@MainActor
struct ProfileRepositoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func make() throws -> (ProfileRepository, ModelContext) {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        return (ProfileRepository(context: context), context)
    }

    @Test func currentIsNilWithoutProfile() throws {
        let (repo, _) = try make()
        #expect(try repo.current() == nil)
        #expect(try repo.isOnboardingComplete() == false)
    }

    @Test func currentPicksOldest() throws {
        let (repo, context) = try make()
        let store = EntityStore<UserProfile>(context: context)
        store.insert(UserProfile(displayName: "yeni"), now: t0.addingTimeInterval(10))
        store.insert(UserProfile(displayName: "eski"), now: t0)
        try store.save()
        #expect(try repo.current()?.displayName == "eski")
    }

    @Test func completeOnboardingCreatesThenUpdates() throws {
        let (repo, context) = try make()
        let created = try repo.completeOnboarding(
            field: .ea, appleUserId: nil, displayName: "Ada", now: t0
        )
        #expect(created.field == .ea && created.displayName == "Ada")
        #expect(created.onboardingCompletedAt == t0 && created.createdAt == t0)
        #expect(try repo.isOnboardingComplete())

        let later = t0.addingTimeInterval(100)
        let updated = try repo.completeOnboarding(
            field: .say, appleUserId: "apple.1", displayName: nil, now: later
        )
        #expect(updated.id == created.id)
        #expect(updated.field == .say && updated.displayName == "Ada")
        #expect(updated.appleUserId == "apple.1")
        #expect(updated.updatedAt == later && updated.onboardingCompletedAt == later)
        #expect(try EntityStore<UserProfile>(context: context).all().count == 1)
    }

    @Test func setAppleUserIdSetsAndClears() throws {
        let (repo, _) = try make()
        try repo.setAppleUserId("x", now: t0)  // profil yok: etkisiz
        #expect(try repo.current() == nil)
        try repo.completeOnboarding(field: .say, appleUserId: nil, displayName: nil, now: t0)
        try repo.setAppleUserId("apple.2", now: t0.addingTimeInterval(1))
        #expect(try repo.current()?.appleUserId == "apple.2")
        try repo.setAppleUserId(nil, now: t0.addingTimeInterval(2))
        #expect(try repo.current()?.appleUserId == nil)
    }
}
