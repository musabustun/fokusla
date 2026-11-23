import Foundation

/// StandBy (şarjda, yatay, kilitli) widget görünüm modeli — SAF. Az bilgi, çok netlik: durum, (odakta) ders adı,
/// hedef satırı, halka oranı. Renk tek başına anlam taşımaz: "Hedef tamam" ve "Odak sürüyor" metindir
/// (gece modunun kırmızı tek tonunda da anlaşılır).
extension WidgetCalc {
    public struct StandByDisplay: Sendable, Equatable {
        public var isRunning: Bool
        public var isGoalReached: Bool
        /// Üst etiket: "Odak sürüyor" / "Bugün".
        public var statusText: String
        /// Yalnızca odak sürerken: ders adı ya da "Serbest çalışma".
        public var titleText: String?
        /// "45 dk kaldı" / "Hedef tamam"; hedef yoksa `nil`.
        public var goalText: String?
        /// "%50"; hedef yoksa `nil`.
        public var percentText: String?
        public var ratio: Double
        public var focusMs: Double
        /// Akarken sayacı sistemin saydırması için başlangıç (`FocusSummary.timerStart`).
        public var timerStart: Date?
        /// VoiceOver cümlesi: "Odak sürüyor, AYT Matematik, 1 sa 15 dk, 45 dk kaldı".
        public var accessibilityText: String
    }

    public static let standByFreeStudyTitle = "Serbest çalışma"

    public static func standBy(focus: FocusSummary, subject: String?) -> StandByDisplay {
        let trimmed = subject?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subjectName = (trimmed?.isEmpty == false) ? trimmed : nil
        let isReached = focus.goal?.isReached == true
        let goalText = focus.goal.map { isReached ? "Hedef tamam" : DailyGoalCalc.remainingText($0) }
        let status = focus.isRunning ? "Odak sürüyor" : "Bugün"
        let title = focus.isRunning ? (subjectName ?? standByFreeStudyTitle) : nil
        let percent = focus.goal.map { "%\(Int(($0.ratio * 100).rounded()))" }
        let parts = [status, title, FocusFormat.durationText(focus.focusMs), goalText].compactMap { $0 }
        return StandByDisplay(
            isRunning: focus.isRunning, isGoalReached: isReached, statusText: status, titleText: title,
            goalText: goalText, percentText: percent, ratio: focus.ratio, focusMs: focus.focusMs,
            timerStart: focus.timerStart, accessibilityText: parts.joined(separator: ", "))
    }

    /// "Odak saati" widget'ının tarih satırı: "19 Kasım Perşembe" (sabit Türkçe tablolar).
    public static func standByDateLine(_ date: Date, calendar: Calendar = .current) -> String {
        TaskFormatting.dayTitle(Identifiers.isoDate(date, calendar: calendar))
    }
}

extension WidgetCalc {
    /// "Odak saati" girdi sayısı (dakika başına bir; 2 saat).
    public static let clockEntryCount = 120

    /// Saat widget'ı: `Text(date, style: .time)` kendi kendine ilerlemez; bu yüzden her dakika başına bir girdi
    /// verilir (ilk girdi içinde bulunulan dakikanın başı). Ertesi gün başlangıcında kesilir ve yenilenir
    /// (tarih satırı + günlük toplam sıfırlanır).
    public static func clockTimelinePlan(now: Date, calendar: Calendar = .current) -> TimelinePlan {
        let minuteStart = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        let midnight = nextMidnight(after: now, calendar: calendar)
        let entries = (0..<clockEntryCount)
            .map { minuteStart.addingTimeInterval(60 * Double($0)) }
            .filter { $0 < midnight }
        let last = entries.last ?? minuteStart
        return TimelinePlan(entries: entries, reloadAfter: Swift.min(last.addingTimeInterval(60), midnight))
    }
}
