import Foundation
import Testing

@testable import FokusDomain

// Saat kadranı hesapları. `now` sabit; `Date()` yok.

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func state(
    _ phase: FocusActivityCalc.Phase, since: TimeInterval, dayStart: TimeInterval? = nil, goal: Int? = nil
) -> FocusActivityCalc.State {
    FocusActivityCalc.State(
        phase: phase, timerStart: now.addingTimeInterval(since), sessionFocusStart: now.addingTimeInterval(since),
        dayFocusStart: dayStart.map { now.addingTimeInterval($0) }, goalMinutes: goal)
}

@Suite("WatchFaceCalc")
struct WatchFaceCalcTests {
    @Test("kayıtlı değer → kadran; bilinmeyen/boş dijitale düşer")
    func faceFromRaw() {
        #expect(WatchFaceCalc.face(from: "analog") == .analog)
        #expect(WatchFaceCalc.face(from: "ring") == .ring)
        #expect(WatchFaceCalc.face(from: "digital") == .digital)
        #expect(WatchFaceCalc.face(from: "x") == .digital)
        #expect(WatchFaceCalc.face(from: nil) == .digital)
    }

    struct HandCase: Sendable, CustomTestStringConvertible {
        let elapsed: TimeInterval
        let minute: Double
        let second: Double
        let hours: Int
        var testDescription: String { "\(elapsed) sn" }
    }

    @Test("ibre açıları ve tam saat", arguments: [
        HandCase(elapsed: 0, minute: 0, second: 0, hours: 0),
        HandCase(elapsed: 15, minute: 1.5, second: 90, hours: 0),
        HandCase(elapsed: 15 * 60, minute: 90, second: 0, hours: 0),
        HandCase(elapsed: 3600, minute: 0, second: 0, hours: 1),
        HandCase(elapsed: 3600 + 30 * 60 + 45, minute: 184.5, second: 270, hours: 1),
        HandCase(elapsed: -20, minute: 0, second: 0, hours: 0),
    ])
    func hands(_ testCase: HandCase) {
        #expect(abs(WatchFaceCalc.minuteHandDegrees(elapsed: testCase.elapsed) - testCase.minute) < 0.0001)
        #expect(abs(WatchFaceCalc.secondHandDegrees(elapsed: testCase.elapsed) - testCase.second) < 0.0001)
        #expect(WatchFaceCalc.completedHours(elapsed: testCase.elapsed) == testCase.hours)
    }

    @Test("geçen süre gelecekteki çapada sıfırdır")
    func elapsedClamp() {
        #expect(WatchFaceCalc.elapsed(state(.focus, since: -90), now: now) == 90)
        #expect(WatchFaceCalc.elapsed(state(.focus, since: 30), now: now) == 0)
    }

    @Test("bugünkü toplam: odakta akar, molada mola başında durur, hedef yoksa nil")
    func dayTotal() {
        #expect(WatchFaceCalc.dayFocusSeconds(state(.focus, since: -60, dayStart: -3600, goal: 120), now: now) == 3600)
        #expect(WatchFaceCalc.dayFocusSeconds(state(.break, since: -600, dayStart: -3600, goal: 120), now: now) == 3000)
        #expect(WatchFaceCalc.dayFocusSeconds(state(.focus, since: -60), now: now) == nil)
    }

    @Test("halka: hedef varsa günlük ilerleme (en çok 1), yoksa geçerli saatin dolan kısmı")
    func ring() {
        #expect(WatchFaceCalc.ringProgress(state(.focus, since: -60, dayStart: -3600, goal: 120), now: now) == 0.5)
        #expect(WatchFaceCalc.ringProgress(state(.focus, since: -60, dayStart: -9000, goal: 120), now: now) == 1)
        #expect(WatchFaceCalc.ringProgress(state(.focus, since: -15 * 60), now: now) == 0.25)
        #expect(WatchFaceCalc.ringProgress(state(.focus, since: -15 * 60, dayStart: -60, goal: 0), now: now) == 0.25)
    }

    struct MinuteCase: Sendable, CustomTestStringConvertible {
        let elapsed: TimeInterval
        let text: String
        var testDescription: String { "\(elapsed) sn → \(text)" }
    }

    @Test(
        "Always On dakikalık metin: tam dakikaya yuvarlanmaz (aşağı), saat varsa iki haneli dakika",
        arguments: [
            MinuteCase(elapsed: -5, text: "0 dk"),
            MinuteCase(elapsed: 0, text: "0 dk"),
            MinuteCase(elapsed: 59, text: "0 dk"),
            MinuteCase(elapsed: 60, text: "1 dk"),
            MinuteCase(elapsed: 23 * 60 + 59, text: "23 dk"),
            MinuteCase(elapsed: 3599, text: "59 dk"),
            MinuteCase(elapsed: 3600, text: "1 sa 00 dk"),
            MinuteCase(elapsed: 3600 + 5 * 60 + 30, text: "1 sa 05 dk"),
            MinuteCase(elapsed: 10 * 3600 + 42 * 60, text: "10 sa 42 dk"),
        ])
    func minuteText(_ testCase: MinuteCase) {
        #expect(WatchFaceCalc.minuteText(elapsed: testCase.elapsed) == testCase.text)
    }

    @Test("Always On bugünkü toplam: hedef kapalıysa yok; molada durur")
    func dayMinuteText() {
        #expect(WatchFaceCalc.dayMinuteText(state(.focus, since: -60), now: now) == nil)
        #expect(WatchFaceCalc.dayMinuteText(state(.focus, since: -60, dayStart: -3 * 3600 - 120), now: now) == "3 sa 02 dk")
        #expect(WatchFaceCalc.dayMinuteText(state(.break, since: -600, dayStart: -1800), now: now) == "20 dk")
    }
}

@Suite("FocusLink tercihleri")
struct FocusLinkPreferencesTests {
    @Test("tercih JSON gidiş-dönüşte korunur; yabancı sözlük çözülmez")
    func roundTrip() throws {
        let preferences = FocusLink.Preferences(palette: "matcha")
        #expect(FocusLink.preferences(from: try #require(FocusLink.payload(preferences))) == preferences)
        #expect(FocusLink.preferences(from: [:]) == nil)
        #expect(FocusLink.preferences(from: [FocusLink.recordsKey: Data([1])]) == nil)
    }
}
