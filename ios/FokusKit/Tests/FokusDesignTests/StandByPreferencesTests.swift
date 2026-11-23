import Foundation
import Testing

@testable import FokusDesign

@Suite("StandByPreferences")
struct StandByPreferencesTests {
    @Test func defaultValues() {
        let value = StandByPreferences.default
        #expect(value.pages == [.stopwatch, .clock, .ring, .music, .summary, .night, .sound])
        #expect(value.clockStyle == .mono)
        #expect(value.accent == nil)
        #expect(!value.tintedDigits)
        #expect(value.backdrop == .gradient)
        #expect(value.nightMode == .auto)
        #expect(value.showsNowPlayingChip)
        #expect(value.musicWidgetPages == [.clock])
        #expect(StandByPreferences.storageKey == "fokus.focus.standby")
    }

    @Test func visiblePagesHidesMusicWhenDisconnected() {
        let value = StandByPreferences.default
        #expect(!value.visiblePages(isMusicConnected: false).contains(.music))
        #expect(value.visiblePages(isMusicConnected: true).contains(.music))
        #expect(value.visiblePages(isMusicConnected: true).count == value.pages.count)
    }

    @Test func visiblePagesFallsBackToStopwatch() {
        let onlyMusic = StandByPreferences.default.with(\.pages, [.music])
        #expect(onlyMusic.visiblePages(isMusicConnected: false) == [.stopwatch])
        #expect(onlyMusic.visiblePages(isMusicConnected: true) == [.music])
        let empty = StandByPreferences.default.with(\.pages, [])
        #expect(empty.visiblePages(isMusicConnected: true) == [.stopwatch])
    }

    @Test func cannotDisableLastNonMusicPage() {
        let value = StandByPreferences.default.with(\.pages, [.clock, .music])
        #expect(!value.canDisable(.clock))
        #expect(value.canDisable(.music))
        #expect(value.toggling(.clock) == value)
        #expect(!value.canDisable(.night))
    }

    @Test func togglingRemovesAndAppends() {
        let value = StandByPreferences.default
        let removed = value.toggling(.ring)
        #expect(!removed.isEnabled(.ring))
        #expect(removed.pages.count == value.pages.count - 1)
        let readded = removed.toggling(.ring)
        #expect(readded.pages.last == .ring)
        let withSubject = value.toggling(.subject)
        #expect(withSubject.pages.last == .subject)
    }

    @Test func movingFromOffsets() {
        let value = StandByPreferences.default.with(\.pages, [.stopwatch, .clock, .ring])
        let moved = value.moving(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(moved.pages == [.clock, .ring, .stopwatch])
    }

    private struct MoveCase: Sendable {
        let page: StandByPage
        let offset: Int
        let expected: [StandByPage]
    }

    private static let moveCases: [MoveCase] = [
        MoveCase(page: .clock, offset: 1, expected: [.stopwatch, .ring, .clock]),
        MoveCase(page: .clock, offset: -1, expected: [.clock, .stopwatch, .ring]),
        MoveCase(page: .stopwatch, offset: -5, expected: [.stopwatch, .clock, .ring]),
        MoveCase(page: .stopwatch, offset: 9, expected: [.clock, .ring, .stopwatch]),
        MoveCase(page: .music, offset: 1, expected: [.stopwatch, .clock, .ring]),
    ]

    @Test(arguments: moveCases)
    private func movingByOffsetClamps(_ testCase: MoveCase) {
        let value = StandByPreferences.default.with(\.pages, [.stopwatch, .clock, .ring])
        #expect(value.moving(testCase.page, by: testCase.offset).pages == testCase.expected)
    }

    @Test func withReplacesFieldAndDeduplicatesPages() {
        let value = StandByPreferences.default.with(\.clockStyle, .thin).with(\.pages, [.clock, .clock, .ring])
        #expect(value.clockStyle == .thin)
        #expect(value.pages == [.clock, .ring])
        #expect(StandByPreferences.default.clockStyle == .mono)
    }

    @Test func paletteFallsBackToApp() {
        #expect(StandByPreferences.default.palette(appPalette: .strawberry) == .strawberry)
        #expect(StandByPreferences.default.with(\.accent, .matcha).palette(appPalette: .strawberry) == .matcha)
    }

    // MARK: Kodlama

    private func decode(_ json: String) -> StandByPreferences {
        StandByPreferences.decoded(from: Data(json.utf8))
    }

    @Test func decodeNilEmptyGarbageGivesDefault() {
        #expect(StandByPreferences.decoded(from: nil) == .default)
        #expect(StandByPreferences.decoded(from: Data()) == .default)
        #expect(decode("not json") == .default)
        #expect(decode("[1,2,3]") == .default)
    }

    @Test func decodePartialJSONKeepsDefaultsForMissing() {
        let value = decode(#"{"clockStyle":"thin","tintedDigits":true}"#)
        #expect(value.clockStyle == .thin)
        #expect(value.tintedDigits)
        #expect(value.pages == StandByPreferences.default.pages)
        #expect(value.backdrop == .gradient)
    }

    @Test func decodeSkipsUnknownPages() {
        let value = decode(#"{"pages":["clock","hologram","ring"]}"#)
        #expect(value.pages == [.clock, .ring])
        #expect(decode(#"{"pages":["hologram"]}"#).pages == StandByPreferences.default.pages)
    }

    @Test func decodeUnknownEnumRawValuesFallBack() {
        let value = decode(#"{"clockStyle":"comic","backdrop":"disco","nightMode":"maybe","accent":"neon"}"#)
        #expect(value.clockStyle == .mono)
        #expect(value.backdrop == .gradient)
        #expect(value.nightMode == .auto)
        #expect(value.accent == nil)
    }

    @Test func roundTrip() {
        let value = StandByPreferences(
            pages: [.night, .clock, .music], clockStyle: .condensed, accent: .blueberry, tintedDigits: true,
            backdrop: .aura, nightMode: .on, showsNowPlayingChip: false)
        #expect(StandByPreferences.decoded(from: value.encoded()) == value)
        #expect(StandByPreferences.decoded(from: StandByPreferences.default.encoded()) == .default)
    }

    @Test func roundTripKeepsMusicWidgetPages() {
        let value = StandByPreferences.default.with(\.musicWidgetPages, [.ring, .stopwatch])
        #expect(StandByPreferences.decoded(from: value.encoded()).musicWidgetPages == [.ring, .stopwatch])
    }

    // MARK: Müzik widget'ı

    @Test func decodeWithoutWidgetKeyUsesDefault() {
        #expect(decode(#"{"clockStyle":"thin"}"#).musicWidgetPages == [.clock])
    }

    @Test func decodeSkipsUnknownAndUnsupportedWidgetPages() {
        let value = decode(#"{"musicWidgetPages":["ring","hologram","music","night","sound","ring","summary"]}"#)
        #expect(value.musicWidgetPages == [.ring, .summary])
        #expect(decode(#"{"musicWidgetPages":[]}"#).musicWidgetPages.isEmpty)
    }

    @Test(arguments: StandByPage.allCases)
    func widgetSupportMatchesPage(page: StandByPage) {
        let expected: Bool = ![StandByPage.music, .night, .sound].contains(page)
        #expect(page.supportsMusicWidget == expected)
    }

    @Test func togglingMusicWidgetAddsAndRemoves() {
        let value = StandByPreferences.default
        let added = value.togglingMusicWidget(.ring)
        #expect(added.hasMusicWidget(.ring))
        #expect(added.musicWidgetPages == [.clock, .ring])
        #expect(!added.togglingMusicWidget(.ring).hasMusicWidget(.ring))
        // Desteklemeyen sayfada değişmez.
        #expect(value.togglingMusicWidget(.music) == value)
        #expect(value.togglingMusicWidget(.night) == value)
    }

    @Test func widgetAndChipAreMutuallyExclusivePerPage() {
        let value = StandByPreferences.default  // widget: clock, çip açık
        #expect(value.showsMusicWidget(on: .clock, isMusicAvailable: true))
        #expect(!value.showsChip(on: .clock, isMusicAvailable: true))
        #expect(!value.showsMusicWidget(on: .ring, isMusicAvailable: true))
        #expect(value.showsChip(on: .ring, isMusicAvailable: true))
        // Müzik yoksa ikisi de yok (mevcut davranış korunur).
        #expect(!value.showsMusicWidget(on: .clock, isMusicAvailable: false))
        #expect(!value.showsChip(on: .ring, isMusicAvailable: false))
        // Çip anahtarı kapalıysa çip yok; widget bağımsız.
        let chipOff = value.with(\.showsNowPlayingChip, false)
        #expect(!chipOff.showsChip(on: .ring, isMusicAvailable: true))
        #expect(chipOff.showsMusicWidget(on: .clock, isMusicAvailable: true))
        // Müzik/gece/ses sayfalarında çip çıkmaz.
        for page in [StandByPage.music, .night, .sound] {
            #expect(!value.showsChip(on: page, isMusicAvailable: true))
        }
    }

    // MARK: Gece modu

    private struct NightCase: Sendable {
        let hour: Int
        let minute: Int
        let expected: Bool
    }

    private static let nightCases: [NightCase] = [
        NightCase(hour: 21, minute: 59, expected: false),
        NightCase(hour: 22, minute: 0, expected: true),
        NightCase(hour: 3, minute: 0, expected: true),
        NightCase(hour: 6, minute: 59, expected: true),
        NightCase(hour: 7, minute: 0, expected: false),
    ]

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3 * 3600) ?? .gmt
        return calendar
    }

    @Test(arguments: nightCases)
    private func autoNightWindow(_ testCase: NightCase) {
        let calendar = Self.calendar
        let date = calendar.date(from: DateComponents(
            year: 2026, month: 11, day: 22, hour: testCase.hour, minute: testCase.minute)) ?? .distantPast
        #expect(StandByNightMode.auto.isActive(at: date, calendar: calendar) == testCase.expected)
        #expect(StandByNightMode.on.isActive(at: date, calendar: calendar))
        #expect(!StandByNightMode.off.isActive(at: date, calendar: calendar))
    }
}
