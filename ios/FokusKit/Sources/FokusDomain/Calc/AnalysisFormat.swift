import Foundation

/// Analiz modülünün Türkçe (tr_TR) sayı/tarih biçimleyicileri ve satır metinleri — saf.
/// Web `features/analysis/format.ts` + `labels.ts` karşılığı.
public enum AnalysisFormat {
    public static let locale = Locale(identifier: "tr_TR")

    public static let noResultsText = "Henüz test yok"
    public static let unknownSourceText = "Kaynak belirtilmedi"

    // MARK: - Sayılar

    /// Net, her zaman iki ondalıkla: `12,75` · `-1,25` · `0,00`.
    public static func formatNet(_ net: Double) -> String {
        (net == 0 ? 0 : net).formatted(.number.locale(locale).precision(.fractionLength(2)))
    }

    /// Oran (0–1) → `%75`.
    public static func formatPercent(_ ratio: Double) -> String {
        (ratio.isFinite ? ratio : 0).formatted(.percent.locale(locale).precision(.fractionLength(0)))
    }

    /// Tam sayı → `1.240`.
    public static func formatCount(_ count: Int) -> String {
        count.formatted(.number.locale(locale).precision(.fractionLength(0)))
    }

    /// Soru sayısı, ör. `24 soru`.
    public static func formatQuestionCount(_ count: Int) -> String {
        "\(formatCount(count)) soru"
    }

    /// Net değeri birimiyle, ör. `12,75 net`.
    public static func formatNetValue(_ net: Double) -> String {
        "\(formatNet(net)) net"
    }

    /// Doğru/yanlış/boş kısaltması, ör. `12D 4Y 4B`.
    public static func formatAnswerCounts(correct: Int, wrong: Int, blank: Int) -> String {
        "\(formatCount(correct))D \(formatCount(wrong))Y \(formatCount(blank))B"
    }

    // MARK: - Tarihler

    /// Anlık zaman → yerel gün, ör. `19 Kas 2026`.
    public static func formatDate(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(style(calendar).day().month(.abbreviated).year())
    }

    /// Anlık zaman → kısa yerel gün, ör. `19 Kas`.
    public static func formatShortDate(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(style(calendar).day().month(.abbreviated))
    }

    /// Yerel takvim günü (`YYYY-MM-DD`) → kısa gün, ör. `19 Kas`. Geçersiz dizge olduğu gibi döner.
    public static func formatShortDay(_ day: ISODate, calendar: Calendar = .current) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
            let date = calendar.date(
                from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
        else { return day }
        return formatShortDate(date, calendar: calendar)
    }

    private static func style(_ calendar: Calendar) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }

    // MARK: - Satır metinleri

    private static func hasResults(_ summary: TestSummary?) -> Bool {
        (summary?.testCount ?? 0) > 0
    }

    /// Ders satırı: `12,75 net · %64` ya da `Henüz test yok`.
    public static func subjectStatText(_ summary: TestSummary?) -> String {
        guard let summary, hasResults(summary) else { return noResultsText }
        return "\(formatNetValue(summary.net)) · \(formatPercent(summary.accuracy))"
    }

    /// Konu satırı değeri: `%75 · 12,75 net` ya da `Henüz test yok`.
    public static func topicStatText(_ summary: TestSummary?) -> String {
        guard let summary, hasResults(summary) else { return noResultsText }
        return "\(formatPercent(summary.accuracy)) · \(formatNetValue(summary.net))"
    }

    /// Konu satırı alt başlığı: `24 soru · son 19 Kas`; test yoksa `nil`.
    public static func topicDetailText(_ summary: TestSummary?, calendar: Calendar = .current) -> String? {
        guard let summary, hasResults(summary) else { return nil }
        let questions = formatQuestionCount(summary.totalQuestions)
        guard let last = summary.lastTakenAt else { return questions }
        return "\(questions) · son \(formatShortDate(last, calendar: calendar))"
    }

    /// Test satırı başlığı: kitap adı / serbest kaynak + etiket, ör. `Karekök · Test 12`.
    public static func resultTitle(bookTitle: String?, sourceName: String?, label: String?) -> String {
        let source = bookTitle ?? nonEmpty(sourceName)
        let place = nonEmpty(label)
        switch (source, place) {
        case let (source?, place?): return "\(source) · \(place)"
        case let (source?, nil): return source
        case let (nil, place?): return place
        case (nil, nil): return unknownSourceText
        }
    }

    /// Test satırı alt başlığı: `19 Kas 2026 · 12D 4Y 4B`.
    public static func resultSubtitle(
        takenAt: Date, correct: Int, wrong: Int, blank: Int, calendar: Calendar = .current
    ) -> String {
        "\(formatDate(takenAt, calendar: calendar)) · \(formatAnswerCounts(correct: correct, wrong: wrong, blank: blank))"
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
