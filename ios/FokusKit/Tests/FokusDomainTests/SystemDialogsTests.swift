import Foundation
import Testing

@testable import FokusDomain

// Siri / Kestirme metinleri ve Odak filtresi ayarları testleri.

private let minuteMs = 60_000.0

struct SystemDialogsTodaySummaryTests {
    struct Case: Sendable {
        let name: String
        let focusMs: Double
        let goalMinutes: Int?
        let expected: String
    }

    @Test(arguments: [
        Case(name: "0 ms", focusMs: 0, goalMinutes: nil, expected: "Bugün henüz odaklanmadın."),
        Case(name: "1 dk altı", focusMs: 59_999, goalMinutes: nil, expected: "Bugün henüz odaklanmadın."),
        Case(name: "tam 1 dk", focusMs: minuteMs, goalMinutes: nil, expected: "Bugün 1 dk odaklandın."),
        Case(name: "90 sn aşağı yuvarlanır", focusMs: 90_000, goalMinutes: nil, expected: "Bugün 1 dk odaklandın."),
        Case(name: "45 dk hedefsiz", focusMs: 45 * minuteMs, goalMinutes: nil, expected: "Bugün 45 dk odaklandın."),
        Case(name: "1 sa 5 dk hedefsiz", focusMs: 65 * minuteMs, goalMinutes: nil, expected: "Bugün 1 sa 5 dk odaklandın."),
        Case(name: "hedefsiz (0 dk hedef kapalı)", focusMs: 45 * minuteMs, goalMinutes: 0, expected: "Bugün 45 dk odaklandın."),
        Case(name: "hedefli kalan 15 dk", focusMs: 45 * minuteMs, goalMinutes: 60, expected: "Bugün 45 dk odaklandın. Hedefine 15 dk kaldı."),
        Case(name: "hedefli kalan 1 sa 30 dk", focusMs: 30 * minuteMs, goalMinutes: 120, expected: "Bugün 30 dk odaklandın. Hedefine 1 sa 30 dk kaldı."),
        Case(name: "hedefli kalan tam saat", focusMs: 60 * minuteMs, goalMinutes: 120, expected: "Bugün 1 sa odaklandın. Hedefine 1 sa kaldı."),
        Case(name: "hiç odak yokken hedef", focusMs: 0, goalMinutes: 60, expected: "Bugün henüz odaklanmadın. Hedefine 1 sa kaldı."),
        Case(name: "hedef adıma normalize edilir (30 → 60)", focusMs: 45 * minuteMs, goalMinutes: 30, expected: "Bugün 45 dk odaklandın. Hedefine 15 dk kaldı."),
        Case(name: "hedefe tam ulaşıldı", focusMs: 60 * minuteMs, goalMinutes: 60, expected: "Bugün 1 sa odaklandın. Günlük hedefine ulaştın."),
        Case(name: "hedef aşıldı", focusMs: 150 * minuteMs, goalMinutes: 120, expected: "Bugün 2 sa 30 dk odaklandın. Günlük hedefine ulaştın."),
        Case(name: "NaN hedefsiz", focusMs: .nan, goalMinutes: nil, expected: "Bugün henüz odaklanmadın."),
        Case(name: "negatif hedefsiz", focusMs: -5 * minuteMs, goalMinutes: nil, expected: "Bugün henüz odaklanmadın."),
        Case(name: "sonsuz negatif hedefsiz", focusMs: -.infinity, goalMinutes: nil, expected: "Bugün henüz odaklanmadın."),
        Case(name: "NaN hedefli", focusMs: .nan, goalMinutes: 60, expected: "Bugün henüz odaklanmadın. Hedefine 1 sa kaldı."),
        Case(name: "negatif hedefli", focusMs: -1, goalMinutes: 60, expected: "Bugün henüz odaklanmadın. Hedefine 1 sa kaldı."),
    ])
    func todaySummary(testCase: Case) {
        #expect(
            SystemDialogs.todaySummary(focusMs: testCase.focusMs, goalMinutes: testCase.goalMinutes)
                == testCase.expected,
            Comment(rawValue: testCase.name))
    }
}

struct SystemDialogsMessageTests {
    struct NameCase: Sendable {
        let name: String?
        let expected: String
    }

    @Test(arguments: [
        NameCase(name: nil, expected: "Odak başladı."),
        NameCase(name: "", expected: "Odak başladı."),
        NameCase(name: "   ", expected: "Odak başladı."),
        NameCase(name: " \n\t ", expected: "Odak başladı."),
        NameCase(name: "Matematik", expected: "Matematik odağı başladı."),
        NameCase(name: "  Fizik \n", expected: "Fizik odağı başladı."),
        NameCase(name: "Türk Dili ve Edebiyatı", expected: "Türk Dili ve Edebiyatı odağı başladı."),
    ])
    func focusStarted(testCase: NameCase) {
        #expect(SystemDialogs.focusStarted(subjectName: testCase.name) == testCase.expected)
    }

    struct FinishedCase: Sendable {
        let focusMs: Double
        let expected: String
    }

    @Test(arguments: [
        FinishedCase(focusMs: 0, expected: "Odak bitti."),
        FinishedCase(focusMs: 999, expected: "Odak bitti."),
        FinishedCase(focusMs: 1000, expected: "Odak bitti. Bu oturumda 1 sn odaklandın."),
        FinishedCase(focusMs: 45_000, expected: "Odak bitti. Bu oturumda 45 sn odaklandın."),
        FinishedCase(focusMs: 25 * minuteMs, expected: "Odak bitti. Bu oturumda 25 dk odaklandın."),
        FinishedCase(focusMs: 65 * minuteMs, expected: "Odak bitti. Bu oturumda 1 sa 5 dk odaklandın."),
        FinishedCase(focusMs: -1000, expected: "Odak bitti."),
        FinishedCase(focusMs: .nan, expected: "Odak bitti."),
        FinishedCase(focusMs: -.infinity, expected: "Odak bitti."),
    ])
    func focusFinished(testCase: FinishedCase) {
        #expect(SystemDialogs.focusFinished(focusMs: testCase.focusMs) == testCase.expected)
    }

    @Test func taskAddedWrapsTitleInTurkishQuotes() {
        #expect(SystemDialogs.taskAdded(title: "Deneme çöz") == "“Deneme çöz” görevi eklendi.")
        #expect(SystemDialogs.taskAdded(title: "İngilizce") == "“İngilizce” görevi eklendi.")
    }

    @Test func staticMessages() {
        #expect(SystemDialogs.focusAlreadyRunning == "Bir odak oturumu zaten sürüyor.")
        #expect(SystemDialogs.noActiveFocus == "Açık bir odak oturumu yok.")
    }

    struct TitleCase: Sendable {
        let raw: String
        let expected: String?
    }

    @Test(arguments: [
        TitleCase(raw: "Deneme çöz", expected: "Deneme çöz"),
        TitleCase(raw: "  Deneme çöz  ", expected: "Deneme çöz"),
        TitleCase(raw: "\n\tTekrar yap \n", expected: "Tekrar yap"),
        TitleCase(raw: "İç  boşluk korunur", expected: "İç  boşluk korunur"),
        TitleCase(raw: "", expected: nil),
        TitleCase(raw: "   ", expected: nil),
        TitleCase(raw: " \n\t ", expected: nil),
    ])
    func normalizedTaskTitle(testCase: TitleCase) {
        #expect(SystemDialogs.normalizedTaskTitle(testCase.raw) == testCase.expected)
    }
}

struct FocusFilterSettingsTests {
    @Test func defaultsSilenceRemindersAndNoAmbientSound() {
        let settings = FocusFilterSettings()
        #expect(settings.silenceReminders == true)
        #expect(settings.ambientSoundRaw == nil)
    }

    @Test func storageKeyIsStable() {
        #expect(FocusFilterSettings.storageKey == "fokus.focusFilter.settings")
    }

    @Test(arguments: [
        FocusFilterSettings(),
        FocusFilterSettings(silenceReminders: false),
        FocusFilterSettings(silenceReminders: true, ambientSoundRaw: "rain"),
        FocusFilterSettings(silenceReminders: false, ambientSoundRaw: "whiteNoise"),
    ])
    func jsonRoundTrip(settings: FocusFilterSettings) throws {
        let data = try #require(settings.encoded())
        #expect(FocusFilterSettings.decode(data) == settings)
    }

    @Test func decodeNilDataIsNil() {
        #expect(FocusFilterSettings.decode(nil) == nil)
    }

    @Test(arguments: ["", "bozuk", "{", "[]", "{}", "{\"silenceReminders\":\"evet\"}", "null"])
    func decodeCorruptOrIncompleteDataIsNil(json: String) {
        #expect(FocusFilterSettings.decode(Data(json.utf8)) == nil)
    }

    @Test func decodeAcceptsMissingOptionalAmbientSound() {
        let decoded = FocusFilterSettings.decode(Data("{\"silenceReminders\":false}".utf8))
        #expect(decoded == FocusFilterSettings(silenceReminders: false, ambientSoundRaw: nil))
    }

    @Test func decodeIgnoresUnknownKeys() {
        let json = "{\"silenceReminders\":true,\"ambientSoundRaw\":\"rain\",\"future\":1}"
        let decoded = FocusFilterSettings.decode(Data(json.utf8))
        #expect(decoded == FocusFilterSettings(silenceReminders: true, ambientSoundRaw: "rain"))
    }
}
