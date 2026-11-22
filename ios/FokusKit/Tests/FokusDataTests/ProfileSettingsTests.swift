import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

@MainActor
struct ProfileSettingsTests {
    private func make() throws -> (ProfileRepository, ModelContext) {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        let repository = ProfileRepository(context: context)
        try repository.completeOnboarding(field: .say, appleUserId: nil, displayName: "Ada")
        return (repository, context)
    }

    @Test func setDisplayNameTrimsAndClearsWhitespaceOnly() throws {
        let (repo, _) = try make()
        try repo.setDisplayName("  Ayşe  ")
        #expect(try repo.current()?.displayName == "Ayşe")
        try repo.setDisplayName("   ")
        #expect(try repo.current()?.displayName == nil)
        try repo.setDisplayName(String(repeating: "a", count: 80))
        #expect(try repo.current()?.displayName?.count == ProfileRepository.displayNameMaxLength)
    }

    @Test func setFieldChangesFieldWithoutTouchingOtherData() throws {
        let (repo, context) = try make()
        let before = try #require(try repo.current())
        let createdAt = before.createdAt
        try repo.setField(.dil)
        let after = try #require(try repo.current())
        #expect(after.field == .dil && after.displayName == "Ada" && after.createdAt == createdAt)
        #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
    }

    @Test func setFieldSameValueDoesNotBumpUpdatedAt() throws {
        let (repo, _) = try make()
        let before = try #require(try repo.current()).updatedAt
        try repo.setField(.say, now: before.addingTimeInterval(100))
        #expect(try repo.current()?.updatedAt == before)
    }

    @Test func dailyGoalIsNormalizedAndClearable() throws {
        let (repo, _) = try make()
        #expect(try repo.current()?.dailyFocusGoalMinutes == nil)
        try repo.setDailyFocusGoal(minutes: 150)
        #expect(try repo.current()?.dailyFocusGoalMinutes == 150)
        try repo.setDailyFocusGoal(minutes: 20)
        #expect(try repo.current()?.dailyFocusGoalMinutes == 60)
        try repo.setDailyFocusGoal(minutes: nil)
        #expect(try repo.current()?.dailyFocusGoalMinutes == nil)
    }

    @Test func settersWithoutProfileAreNoOps() throws {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        let repo = ProfileRepository(context: context)
        try repo.setDisplayName("x")
        try repo.setField(.ea)
        try repo.setDailyFocusGoal(minutes: 120)
        #expect(try repo.current() == nil)
    }
}
