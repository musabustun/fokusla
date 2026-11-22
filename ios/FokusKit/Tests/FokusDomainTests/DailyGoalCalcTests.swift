import Foundation
import Testing

@testable import FokusDomain

struct DailyGoalCalcTests {
    private let minute = 60_000.0

    @Test func optionsAreOneToTenHoursInHalfHourSteps() {
        #expect(DailyGoalCalc.options.first == 60)
        #expect(DailyGoalCalc.options.last == 600)
        #expect(DailyGoalCalc.options.count == 19)
        #expect(DailyGoalCalc.options.contains(90))
    }

    @Test(arguments: [
        (nil as Int?, nil as Int?), (0, nil), (-30, nil),
        (10, 60), (60, 60), (89, 90), (74, 60), (75, 90), (600, 600), (900, 600),
    ])
    func normalizesToValidGoal(input: Int?, expected: Int?) {
        #expect(DailyGoalCalc.normalized(input) == expected)
    }

    @Test func progressIsNilWhenGoalDisabled() {
        #expect(DailyGoalCalc.progress(focusMs: 5 * minute, goalMinutes: nil) == nil)
        #expect(DailyGoalCalc.progress(focusMs: 5 * minute, goalMinutes: 0) == nil)
        #expect(DailyGoalCalc.isReached(focusMs: 999 * minute, goalMinutes: nil) == false)
    }

    @Test func progressBelowGoal() throws {
        let progress = try #require(DailyGoalCalc.progress(focusMs: 30 * minute, goalMinutes: 120))
        #expect(progress.ratio == 0.25)
        #expect(progress.remainingMs == 90 * minute)
        #expect(progress.isReached == false)
        #expect(progress.goalMinutes == 120)
    }

    @Test func progressAtExactlyGoalIsReached() throws {
        let progress = try #require(DailyGoalCalc.progress(focusMs: 120 * minute, goalMinutes: 120))
        #expect(progress.ratio == 1 && progress.remainingMs == 0 && progress.isReached)
    }

    @Test func progressAboveGoalIsCappedAtOne() throws {
        let progress = try #require(DailyGoalCalc.progress(focusMs: 300 * minute, goalMinutes: 120))
        #expect(progress.ratio == 1 && progress.remainingMs == 0 && progress.isReached)
        #expect(progress.focusMs == 300 * minute)
    }

    @Test(arguments: [-5.0, .nan, -.infinity])
    func invalidFocusCountsAsZero(focusMs: Double) throws {
        let progress = try #require(DailyGoalCalc.progress(focusMs: focusMs, goalMinutes: 60))
        #expect(progress.focusMs == 0 && progress.ratio == 0 && progress.remainingMs == 60 * minute)
    }

    @Test(arguments: [(45, "45 dk"), (60, "1 saat"), (90, "1 saat 30 dk"), (600, "10 saat")])
    func goalText(minutes: Int, expected: String) {
        #expect(DailyGoalCalc.goalText(minutes: minutes) == expected)
    }

    @Test(arguments: [
        (0.0, "2 sa kaldı"), (30.0, "1 sa 30 dk kaldı"), (119.5, "1 dk kaldı"), (60.0, "1 sa kaldı"),
        (90.0, "30 dk kaldı"), (120.0, "Hedef tamamlandı"), (200.0, "Hedef tamamlandı"),
    ])
    func remainingText(focusMinutes: Double, expected: String) throws {
        let progress = try #require(DailyGoalCalc.progress(focusMs: focusMinutes * minute, goalMinutes: 120))
        #expect(DailyGoalCalc.remainingText(progress) == expected)
    }
}
