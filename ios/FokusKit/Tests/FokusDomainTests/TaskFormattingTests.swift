import Foundation
import Testing

@testable import FokusDomain

// Görev metin biçimlendiricileri testleri — web `web/src/features/tasks/format.test.ts` ile aynı
// vakalar (aynı girdi/çıktı değerleri).

// MARK: - gün adları

@Suite("gün adları")
struct TaskFormattingWeekdayNameTests {
    @Test("hafta günü → kısa / uzun ad", arguments: [
        (1, "Pzt", "Pazartesi"),
        (2, "Sal", "Salı"),
        (3, "Çar", "Çarşamba"),
        (4, "Per", "Perşembe"),
        (5, "Cum", "Cuma"),
        (6, "Cmt", "Cumartesi"),
        (7, "Paz", "Pazar"),
    ])
    func names(weekday: Int, short: String, long: String) {
        #expect(TaskFormatting.weekdayShortName(weekday) == short)
        #expect(TaskFormatting.weekdayLongName(weekday) == long)
    }

    @Test("ad tabloları Pazartesi→Pazar sıralı, 7 elemanlı")
    func tables() {
        #expect(TaskFormatting.weekdayShortNames.count == 7)
        #expect(TaskFormatting.weekdayLongNames.count == 7)
        #expect(TaskFormatting.weekdayShortNames.first == "Pzt")
        #expect(TaskFormatting.weekdayLongNames.last == "Pazar")
        #expect(TaskFormatting.monthNames.count == 12)
    }

    @Test("aralık dışı değerler 7'ye göre döner", arguments: [
        (0, "Paz", "Pazar"),
        (8, "Pzt", "Pazartesi"),
        (9, "Sal", "Salı"),
        (14, "Paz", "Pazar"),
        (-1, "Cmt", "Cumartesi"),
        (-6, "Pzt", "Pazartesi"),
    ])
    func wrapAround(weekday: Int, short: String, long: String) {
        #expect(TaskFormatting.weekdayShortName(weekday) == short)
        #expect(TaskFormatting.weekdayLongName(weekday) == long)
    }
}

// MARK: - recurrenceText

@Suite("recurrenceText")
struct TaskFormattingRecurrenceTextTests {
    private static func weekly(_ weekdays: [Int]) -> RecurrenceRule {
        RecurrenceRule(frequency: .weekly, weekdays: weekdays)
    }

    @Test("kural → metin", arguments: [
        (RecurrenceRule(frequency: .daily, weekdays: []), "Her gün"),
        (weekly([1, 2, 3, 4, 5]), "Hafta içi"),
        (weekly([5, 4, 3, 2, 1]), "Hafta içi"),
        (weekly([6, 7]), "Hafta sonu"),
        (weekly([1, 2, 3, 4, 5, 6, 7]), "Her gün"),
        (weekly([1, 3, 5]), "Pzt, Çar, Cum"),
        (weekly([7, 1, 1]), "Pzt, Paz"),
        (weekly([]), "Gün seçilmedi"),
    ])
    func table(rule: RecurrenceRule, expected: String) {
        #expect(TaskFormatting.recurrenceText(rule) == expected)
    }

    @Test("günlük kuralda seçili günler yok sayılır")
    func dailyIgnoresWeekdays() {
        #expect(TaskFormatting.recurrenceText(RecurrenceRule(frequency: .daily, weekdays: [1, 2])) == "Her gün")
    }

    @Test("bilinmeyen sıklık → Her gün")
    func unknownFrequency() {
        var rule = RecurrenceRule(frequency: .weekly, weekdays: [1, 3])
        rule.frequency = "monthly"
        #expect(rule.frequencyValue == nil)
        #expect(TaskFormatting.recurrenceText(rule) == "Her gün")
    }
}

// MARK: - tarih biçimleri

@Suite("tarih biçimleri")
struct TaskFormattingDateTests {
    @Test("gün başlığı ve uzun tarih", arguments: [
        ("2026-11-19", "19 Kasım Perşembe", "19 Kasım 2026"),
        ("2026-01-01", "1 Ocak Perşembe", "1 Ocak 2026"),
        ("2028-02-29", "29 Şubat Salı", "29 Şubat 2028"),
    ])
    func titles(day: String, title: String, long: String) {
        #expect(TaskFormatting.dayTitle(day) == title)
        #expect(TaskFormatting.longDate(day) == long)
    }
}

// MARK: - dueText

@Suite("dueText")
struct TaskFormattingDueTextTests {
    @Test("kalan gün → metin", arguments: [
        (0, "Bugün"),
        (1, "Yarın"),
        (2, "2 gün kaldı"),
        (1500, "1.500 gün kaldı"),
        (-1, "Dün"),
        (-3, "3 gün gecikti"),
        (-1500, "1.500 gün gecikti"),
    ])
    func table(days: Int, expected: String) {
        #expect(TaskFormatting.dueText(daysUntil: days) == expected)
    }
}

// MARK: - quantityText

@Suite("quantityText")
struct TaskFormattingQuantityTextTests {
    @Test("hedef / gerçekleşen / birim → metin", arguments: [
        (50 as Int?, nil as Int?, "soru" as String?, "50 soru" as String?),
        (50, 42, "soru", "42/50 soru"),
        (nil, 42, "sayfa", "42 sayfa"),
        (50, nil, nil, "50"),
        (1000, 1200, "  soru ", "1.200/1.000 soru"),
        (nil, nil, "soru", nil),
        (nil, nil, nil, nil),
        (50, nil, "   ", "50"),
        (50, 42, "", "42/50"),
        (nil, 12_345, "soru", "12.345 soru"),
    ])
    func table(target: Int?, actual: Int?, unit: String?, expected: String?) {
        #expect(TaskFormatting.quantityText(target: target, actual: actual, unit: unit) == expected)
    }
}

// MARK: - sayılar

@Suite("sayılar")
struct TaskFormattingNumberTests {
    @Test("tr-TR biçimini kullanır")
    func trTR() {
        #expect(TaskFormatting.number(12345) == "12.345")
        #expect(TaskFormatting.number(7) == "7")
        #expect(TaskFormatting.percent(0.571) == "%57")
        #expect(TaskFormatting.percent(1) == "%100")
        #expect(TaskFormatting.percent(0) == "%0")
        #expect(TaskFormatting.streakText(3) == "3 gün seri")
        #expect(TaskFormatting.streakText(1200) == "1.200 gün seri")
    }

    @Test("rateText varsayılan pencere 7 gün")
    func rateText() {
        #expect(TaskFormatting.rateText(0.571) == "Son 7 gün %57")
        #expect(TaskFormatting.rateText(1, windowDays: 30) == "Son 30 gün %100")
        #expect(TaskFormatting.rateText(0.5, windowDays: 1500) == "Son 1.500 gün %50")
    }
}
